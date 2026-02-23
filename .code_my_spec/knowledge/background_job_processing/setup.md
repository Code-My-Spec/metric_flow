# Background Job Processing: Setup, Patterns, and Testing

Practical reference for Oban usage in MetricFlow. All implementation choices
follow the decisions recorded in
`docs/architecture/decisions/background_job_processing.md`.

---

## 1. Current State of Oban in the Project

Oban is already wired into the application and running. Do not add it again.

**`mix.exs`**
```elixir
{:oban, "~> 2.2"}
```

**`lib/metric_flow/application.ex`**
```elixir
{Oban, Application.fetch_env!(:metric_flow, Oban)}
```

**`config/config.exs`** — current (bare minimum, needs to be expanded)
```elixir
config :metric_flow, Oban,
  repo: MetricFlow.Infrastructure.Repo,
  queues: [default: 10, sync: 5]
```

**`config/test.exs`** — already correct, do not change
```elixir
config :metric_flow, Oban, testing: :manual
```

---

## 2. Production Configuration

The bare config above must be expanded to add plugins before any workers are
deployed. The full target configuration is:

```elixir
# config/config.exs
config :metric_flow, Oban,
  repo: MetricFlow.Infrastructure.Repo,
  queues: [
    default: 10,
    sync: 5,
    correlations: 3
  ],
  plugins: [
    {Oban.Plugins.Pruner, max_age: 604_800},
    {Oban.Plugins.Lifeline, rescue_after: :timer.minutes(30)},
    {Oban.Plugins.Cron,
     crontab: [
       {"0 2 * * *", MetricFlow.DataSync.Scheduler, queue: :sync, max_attempts: 1}
     ]}
  ]
```

### Queue rationale

| Queue | Concurrency | Workload |
|-------|-------------|---------|
| `default` | 10 | General tasks, `RefreshMaterializedViewsWorker` |
| `sync` | 5 | Network-bound external API calls; 5 prevents rate-limit pile-ups |
| `correlations` | 3 | CPU-bound Pearson calculations; low to avoid node saturation |

### Plugin rationale

- **Pruner** — deletes completed and discarded jobs older than 7 days. At daily
  sync volume (hundreds of integrations) this prevents unbounded table growth.
- **Lifeline** — rescues jobs stuck in `:executing` after 30 minutes. Handles
  node crashes without manual intervention on Fly.io.
- **Cron** — registers the `Scheduler` at `0 2 * * *` UTC. Uses database
  uniqueness internally; safe on multi-node deployments without extra config.

---

## 3. Database Migration

The `oban_jobs` table is created by Oban's own migration. If it does not exist,
add a migration:

```bash
mix ecto.gen.migration add_oban_jobs_table
```

Then in the generated file:

```elixir
defmodule MetricFlow.Infrastructure.Repo.Migrations.AddObanJobsTable do
  use Ecto.Migration

  def up, do: Oban.Migration.up(version: 12)
  def down, do: Oban.Migration.down(version: 1)
end
```

Check hex.pm/oban release notes for the current recommended migration version.
As of Oban 2.x the recommended version is 12.

---

## 4. Worker Modules

Workers live in their bounded context. The `Boundary` library enforces that
workers only call functions exported by their declared dependencies. Do not
call across context boundaries from inside a worker `perform/1`.

### Module placement

```
lib/metric_flow/data_sync/scheduler.ex         -> MetricFlow.DataSync.Scheduler
lib/metric_flow/data_sync/sync_worker.ex       -> MetricFlow.DataSync.SyncWorker
lib/metric_flow/correlations/correlation_worker.ex -> MetricFlow.Correlations.CorrelationWorker
```

### DataSync.Scheduler

Cron-triggered. Queries all active integrations and enqueues one `SyncWorker`
job per integration. Must not retry — if it fails, the next day's cron re-runs
it. Retrying a partial run risks double-scheduling sync jobs.

```elixir
defmodule MetricFlow.DataSync.Scheduler do
  @moduledoc """
  Daily cron job that enqueues one SyncWorker per active integration.

  Triggered at 02:00 UTC by Oban.Plugins.Cron. Never retries: if the
  scheduler itself fails, the next cron invocation picks up. Retrying
  risks double-scheduling sync jobs for integrations that were already
  enqueued before the failure.
  """

  use Oban.Worker,
    queue: :sync,
    max_attempts: 1

  alias MetricFlow.DataSync.SyncWorker
  alias MetricFlow.Integrations

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    integrations = Integrations.list_all_active_integrations()

    Enum.each(integrations, fn integration ->
      %{integration_id: integration.id, user_id: integration.user_id}
      |> SyncWorker.new()
      |> Oban.insert()
    end)

    :ok
  end
end
```

**Why `Integrations.list_all_active_integrations/0`?** The scheduler operates
across all users and has no scope context. This function is already defined and
exported on the `MetricFlow.Integrations` context.

### DataSync.SyncWorker

The main data-fetching worker. Uniqueness on `integration_id` prevents duplicate
syncs for the same integration within a one-hour scheduling window.

```elixir
defmodule MetricFlow.DataSync.SyncWorker do
  @moduledoc """
  Fetches metrics from a single external API integration and persists them.

  Enqueued by DataSync.Scheduler for daily runs, or directly via the
  LiveView for manual "Sync Now" triggers. Uniqueness on integration_id
  with a 1-hour period prevents duplicate concurrent syncs for the same
  integration.
  """

  use Oban.Worker,
    queue: :sync,
    max_attempts: 3,
    unique: [
      fields: [:args],
      keys: [:integration_id],
      period: 3_600,
      states: [:available, :scheduled, :executing]
    ]

  alias MetricFlow.Correlations.CorrelationWorker
  alias MetricFlow.Integrations
  alias MetricFlow.Metrics
  alias MetricFlow.Users.Scope

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"integration_id" => integration_id, "user_id" => user_id}}) do
    scope = Scope.for_user_id(user_id)
    integration = Integrations.get_integration_by_id(integration_id)

    with {:ok, fresh_integration} <- maybe_refresh_token(scope, integration),
         {:ok, metrics} <- fetch_metrics(fresh_integration),
         :ok <- persist_metrics(scope, metrics) do
      enqueue_correlation_worker(scope)
      :ok
    end
  end

  # Custom backoff: rate-limited jobs back off 5 minutes regardless of attempt
  # count. All other failures use standard exponential backoff.
  @impl Oban.Worker
  def backoff(%Oban.Job{unsaved_error: %{reason: :rate_limited}}) do
    300 + :rand.uniform(60)
  end

  def backoff(%Oban.Job{attempt: attempt}) do
    trunc(:math.pow(attempt, 4)) + 15 + :rand.uniform(30)
  end

  # --- Private helpers ---

  defp maybe_refresh_token(scope, integration) do
    if Integrations.Integration.expired?(integration) do
      Integrations.refresh_token(scope, integration)
    else
      {:ok, integration}
    end
  end

  defp fetch_metrics(_integration) do
    # TODO: dispatch to provider-specific fetch module
    {:ok, []}
  end

  defp persist_metrics(_scope, []), do: :ok

  defp persist_metrics(scope, metrics) do
    Enum.reduce_while(metrics, :ok, fn metric, _acc ->
      case Metrics.create_metric(scope, metric) do
        {:ok, _} -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp enqueue_correlation_worker(%Scope{account_id: account_id}) do
    %{account_id: account_id}
    |> CorrelationWorker.new()
    |> Oban.insert()
  end
end
```

**Job chaining note:** `CorrelationWorker` is enqueued from inside `perform/1`
after a successful sync. This is the standard Oban pattern for job chaining.
The uniqueness constraint on `CorrelationWorker` (24-hour period on
`account_id`) means repeated syncs for the same account within a day produce
exactly one correlation job.

### Correlations.CorrelationWorker

CPU-bound. Uniqueness covers the `(account_id, metric_id, goal_metric_id)`
triple to prevent recalculating the same pair multiple times in one sync cycle.

The full implementation is in
`docs/knowledge/correlation_engine/implementation_patterns.md`. The Oban
configuration for this worker is:

```elixir
use Oban.Worker,
  queue: :correlations,
  max_attempts: 3,
  unique: [
    fields: [:args],
    keys: [:account_id, :metric_id, :goal_metric_id],
    period: 86_400,
    states: [:available, :scheduled, :executing]
  ]
```

---

## 5. Uniqueness Constraints

Oban implements uniqueness at the database level using a partial unique index
on `oban_jobs`. This works safely across Fly.io nodes.

### SyncWorker: per-integration, 1-hour window

```elixir
unique: [
  fields: [:args],
  keys: [:integration_id],
  period: 3_600,
  states: [:available, :scheduled, :executing]
]
```

- `fields: [:args]` — uniqueness is scoped to the args column
- `keys: [:integration_id]` — only this key within args is compared
- `period: 3_600` — 1 hour; covers the scheduler's single run window
- `states: [...]` — a completed or discarded job does not block a new sync

**Consequence:** If a manual "Sync Now" is triggered while an automatic sync is
already enqueued or executing for the same integration, the manual job will be
silently dropped and `Oban.insert/1` returns `{:ok, %Job{conflict?: true}}`.
The LiveView should handle this case:

```elixir
case Oban.insert(SyncWorker.new(args)) do
  {:ok, %Oban.Job{conflict?: true}} ->
    {:noreply, assign(socket, :sync_status, :already_running)}

  {:ok, _job} ->
    {:noreply, assign(socket, :sync_status, :enqueued)}

  {:error, changeset} ->
    {:noreply, assign(socket, :sync_error, changeset)}
end
```

### CorrelationWorker: per-account-metric-pair, 24-hour window

```elixir
unique: [
  fields: [:args],
  keys: [:account_id, :metric_id, :goal_metric_id],
  period: 86_400,
  states: [:available, :scheduled, :executing]
]
```

This means even if 10 integrations sync for the same account in one day, the
correlation recalculation for each metric pair runs at most once.

---

## 6. Error Handling

### Return values from `perform/1`

Workers must return structured values. Never let exceptions escape unless
intentional.

| Return value | Oban behaviour |
|---|---|
| `:ok` | Job marked `:completed` |
| `{:ok, _}` | Job marked `:completed` |
| `{:error, reason}` | Job retried with exponential backoff; after max_attempts moves to `:discarded` |
| `{:snooze, seconds}` | Job rescheduled `seconds` from now; does not consume a retry attempt |
| raise/throw | Job retried; exception captured in `unsaved_error` |

### Rate limiting with snooze

When an external API returns HTTP 429, return `{:snooze, seconds}` rather than
`{:error, ...}`. This delays the job without burning a retry attempt:

```elixir
defp fetch_from_api(integration) do
  case Req.get(api_url, headers: auth_headers(integration)) do
    {:ok, %{status: 200, body: body}} ->
      {:ok, body}

    {:ok, %{status: 429, headers: headers}} ->
      retry_after = parse_retry_after(headers)
      {:snooze, retry_after}

    {:ok, %{status: status}} ->
      {:error, {:http_error, status}}

    {:error, reason} ->
      {:error, {:network_error, reason}}
  end
end

defp parse_retry_after(headers) do
  case List.keyfind(headers, "retry-after", 0) do
    {_, value} -> String.to_integer(value)
    nil -> 300
  end
end
```

### Custom backoff for rate limiting

The `backoff/1` callback on `SyncWorker` applies a 5-minute delay specifically
for rate-limit failures, overriding the default exponential formula:

```elixir
@impl Oban.Worker
def backoff(%Oban.Job{unsaved_error: %{reason: :rate_limited}}) do
  300 + :rand.uniform(60)
end

def backoff(%Oban.Job{attempt: attempt}) do
  trunc(:math.pow(attempt, 4)) + 15 + :rand.uniform(30)
end
```

The `:rand.uniform/1` adds jitter to avoid thundering herd when many integrations
hit a rate limit simultaneously.

### Token expiry handling

When a token is expired and the refresh also fails, return `{:error, :token_expired}`.
This lets Oban retry. If refresh consistently fails across all 3 attempts, the
job moves to `:discarded`. Log the failure and update the integration's status
so the user can see it in the UI.

```elixir
defp maybe_refresh_token(scope, integration) do
  cond do
    not Integrations.Integration.expired?(integration) ->
      {:ok, integration}

    Integrations.Integration.has_refresh_token?(integration) ->
      case Integrations.refresh_token(scope, integration) do
        {:ok, refreshed} -> {:ok, refreshed}
        {:error, _reason} -> {:error, :token_expired}
      end

    true ->
      {:error, :no_refresh_token}
  end
end
```

---

## 7. Job Chaining Pattern

MetricFlow uses the "enqueue from perform" pattern for chaining
`SyncWorker` -> `CorrelationWorker`. This is the standard Oban approach.

```
Cron (02:00 UTC)
  |
  v
DataSync.Scheduler (queue: :sync, max_attempts: 1)
  |
  | Oban.insert() for each active integration
  v
DataSync.SyncWorker (queue: :sync, max_attempts: 3)
  |
  | On :ok, Oban.insert()
  v
Correlations.CorrelationWorker (queue: :correlations, max_attempts: 3)
```

The uniqueness constraint on `CorrelationWorker` ensures that enqueueing from
multiple `SyncWorker` completions within 24 hours is idempotent per account.

To enqueue from inside `perform/1`, always use `Oban.insert/1` (not
`Oban.insert!/1`). Log but do not fail the parent job if the child enqueue
fails:

```elixir
case %{account_id: account_id} |> CorrelationWorker.new() |> Oban.insert() do
  {:ok, _job} -> :ok
  {:error, changeset} -> Logger.warning("Failed to enqueue CorrelationWorker", changeset: changeset)
end
```

---

## 8. Testing with Oban.Testing

### Setup in DataCase

Add `use Oban.Testing` to `test/support/data_case.ex` so all data-layer tests
have access to the Oban assertions:

```elixir
defmodule MetricFlowTest.DataCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      alias MetricFlow.Infrastructure.Repo
      use Oban.Testing, repo: MetricFlow.Infrastructure.Repo  # add this line

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import MetricFlowTest.DataCase
    end
  end

  setup tags do
    MetricFlowTest.DataCase.setup_sandbox(tags)
    :ok
  end

  # ... rest of file unchanged
end
```

### Testing mode: `:manual` (default in test env)

Jobs are inserted into the database but never executed. Use `assert_enqueued` to
verify jobs were scheduled with the correct args.

```elixir
defmodule MetricFlow.DataSync.SchedulerTest do
  use MetricFlowTest.DataCase

  alias MetricFlow.DataSync.Scheduler
  alias MetricFlow.DataSync.SyncWorker

  test "enqueues one SyncWorker per active integration" do
    user = user_fixture()
    integration = integration_fixture(user)

    perform_job(Scheduler, %{})

    assert_enqueued(
      worker: SyncWorker,
      args: %{integration_id: integration.id, user_id: user.id}
    )
  end

  test "does not enqueue jobs when there are no integrations" do
    perform_job(Scheduler, %{})

    refute_enqueued(worker: SyncWorker)
  end
end
```

### Testing worker behavior: `perform_job/2`

Use `perform_job/2` rather than calling `perform/1` directly. It stringifies
args (matching how Oban stores them) and validates the worker contract.

```elixir
defmodule MetricFlow.DataSync.SyncWorkerTest do
  use MetricFlowTest.DataCase

  alias MetricFlow.DataSync.SyncWorker

  test "returns :ok for a valid integration" do
    user = user_fixture()
    integration = integration_fixture(user)

    assert :ok =
             perform_job(SyncWorker, %{
               integration_id: integration.id,
               user_id: user.id
             })
  end

  test "returns {:error, :token_expired} when token refresh fails" do
    user = user_fixture()
    integration = expired_integration_without_refresh_token_fixture(user)

    assert {:error, :no_refresh_token} =
             perform_job(SyncWorker, %{
               integration_id: integration.id,
               user_id: user.id
             })
  end

  test "enqueues CorrelationWorker after successful sync" do
    user = user_fixture()
    integration = integration_fixture(user)

    perform_job(SyncWorker, %{
      integration_id: integration.id,
      user_id: user.id
    })

    assert_enqueued(worker: MetricFlow.Correlations.CorrelationWorker)
  end
end
```

### Inline mode for end-to-end scenarios

When a test needs to verify both enqueueing and execution in one flow (e.g., a
LiveView test that clicks "Sync Now" and needs to assert on the sync result),
switch to `:inline` mode for that test body:

```elixir
test "sync now button triggers sync and shows result", %{conn: conn} do
  user = user_fixture()
  integration = integration_fixture(user)
  conn = log_in_user(conn, user)

  Oban.Testing.with_testing_mode(:inline, fn ->
    {:ok, view, _html} = live(conn, ~p"/integrations")

    view
    |> element("[data-role=integration]:first-child button", "Sync Now")
    |> render_click()

    html = render(view)
    assert html =~ "Sync complete"
  end)
end
```

Do not use `:inline` mode as the default for all tests — it executes jobs
synchronously in the test process, which can make tests slow and sensitive to
external dependencies. Reserve it for integration-level tests where you need to
verify the full execution path.

### `assert_enqueued` reference

```elixir
# Assert a job exists with specific worker and args
assert_enqueued(worker: SyncWorker, args: %{integration_id: 42})

# Assert with queue
assert_enqueued(worker: SyncWorker, queue: :sync)

# Assert no such job exists
refute_enqueued(worker: SyncWorker, args: %{integration_id: 42})

# Get all enqueued jobs for inspection
jobs = all_enqueued(worker: SyncWorker)
assert length(jobs) == 3
```

`assert_enqueued` performs a partial match on `:args` — you only need to specify
the keys you care about, not the full args map.

---

## 9. Development Environment Note

The `Oban.Plugins.Cron` configuration registers the `Scheduler` at application
boot. In development, this will attempt to enqueue a `Scheduler` job at 02:00
UTC. If you want to suppress this during local development, move the plugins
config to a `config/prod.exs` block, or add a dev-specific override:

```elixir
# config/dev.exs — omit plugins entirely in dev if cron is undesirable
config :metric_flow, Oban,
  repo: MetricFlow.Infrastructure.Repo,
  queues: [default: 10, sync: 5, correlations: 3]
```

The test config's `testing: :manual` already disables all plugins in the test
environment — no further change needed there.

---

## 10. Oban Web Dashboard (Deferred)

`oban_web` (Apache 2.0 since v2.11) provides a job monitoring UI. It is not
yet added as a dependency. Add it when operational visibility becomes a priority
in staging or production:

```elixir
# mix.exs
{:oban_web, "~> 2.11"}
```

Mount it in the router under an authenticated admin scope:

```elixir
# lib/metric_flow_web/router.ex
import Oban.Web.Router

scope "/" do
  pipe_through [:browser, :require_authenticated_user]
  oban_dashboard "/oban"
end
```

The dashboard is read-write by default and allows retrying, cancelling, and
draining queues. Restrict access to admin users in production before deploying.
