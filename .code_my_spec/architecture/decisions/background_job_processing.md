# Background Job Processing

**Status:** Accepted
**Date:** 2026-02-21

## Context

MetricFlow requires reliable background job processing for three distinct workloads:

- **Daily sync scheduling** (`DataSync.Scheduler`) — a cron-triggered job that runs at 2am UTC to enqueue one `SyncWorker` job per active integration across all users.
- **Per-integration data sync** (`DataSync.SyncWorker`) — fetches metrics from external APIs (Google Analytics, Google Ads, Facebook Ads, QuickBooks), persists them via the Metrics context, and records a `SyncHistory` entry. Calls external HTTP APIs and must handle token expiry, network errors, and rate limits.
- **Correlation calculations** (`Correlations.CorrelationWorker`) — CPU-intensive Pearson coefficient calculations over time-series data. Triggered after each successful sync.

These jobs have different characteristics: the scheduler is fire-and-forget with low volume, sync workers are network-bound and may fail on external API errors, and correlation workers are CPU-bound. All three require retry handling, visibility into failure, and protection against duplicate execution.

The project already has `{:oban, "~> 2.2"}` in `mix.exs` and Oban is started in `application.ex` as `{Oban, Application.fetch_env!(:metric_flow, Oban)}`. The existing config defines two queues: `[default: 10, sync: 5]`. The deployment target is Fly.io with managed PostgreSQL.

This decision formalizes the use of Oban, specifies the queue design, plugin configuration, uniqueness strategy, retry approach, pruning policy, and testing patterns to use as each worker is implemented.

## Options Considered

### Option A: Oban (open-source, `~> 2.x`)

The de facto standard for background job processing in Elixir applications. Uses PostgreSQL as the job store, giving jobs the same ACID guarantees as application data. No Redis or additional infrastructure required.

- **Pros:**
  - Already a project dependency; zero adoption cost.
  - PostgreSQL-backed job storage aligns with the existing stack. No new stateful service to operate on Fly.io.
  - Built-in plugins handle the full production lifecycle: `Cron` for scheduling, `Pruner` for cleanup, `Stager` for transitioning scheduled jobs, `Lifeline` for recovering jobs orphaned by node crashes.
  - `Oban.Testing` provides `assert_enqueued`, `perform_job`, and `:manual`/`:inline` modes that integrate naturally with the existing `Ecto.Adapters.SQL.Sandbox` test setup.
  - Unique job constraints at the database level prevent duplicate sync jobs for the same integration within a configurable window.
  - Oban Web dashboard (`oban_web`) is now open source (Apache 2.0 since v2.11) and freely usable for job monitoring.
  - Active development: v2.20.3 current as of early 2026, requires Elixir 1.15+ and PostgreSQL 12+, both satisfied by the project.
  - Safe for multi-node Fly.io deployments: PostgreSQL advisory locks prevent duplicate execution across nodes; `Plugins.Cron` uses database uniqueness to prevent duplicate cron insertions without additional configuration.

- **Cons:**
  - The existing `queues: [default: 10, sync: 5]` config is bare minimum. Production-grade configuration requires adding plugins (Pruner, Lifeline, Cron) before workers are deployed.
  - `sync: 5` concurrency needs to be evaluated against external API rate limits per provider; may need per-queue or per-worker adjustments.
  - No built-in job monitoring UI out of the box — requires adding `oban_web` dependency separately if desired.

### Option B: Oban Pro

A paid superset of Oban that adds workflows, chunks, global concurrency limits, dynamic plugins, worker hooks, structured arguments, and decorators. Pro also previously bundled the Oban Web dashboard, but that is now freely available.

- **Pros:**
  - Workflow support would allow chaining `SyncWorker` -> `RefreshMaterializedViewsWorker` -> `CorrelationWorker` with dependency semantics, rather than manual job chaining.
  - Global concurrency limits would allow capping total concurrent external API calls across all queues, which could help respect aggregate rate limits across Google, Facebook, and QuickBooks.
  - `DynamicCron` plugin allows runtime modification of cron schedules without redeployment.

- **Cons:**
  - Paid subscription required. At early SaaS scale (10–100 accounts) the cost is not justified by the additional features.
  - The workflow and global concurrency features address complexity that the project does not yet have. The `DataSync` spec chains workers by enqueueing from within `perform/1`, which is sufficient for the current design.
  - None of the current worker specs reference Pro-specific APIs.

### Option C: Custom GenServer / Task.Supervisor

Implement scheduling with `:timer.send_interval` or a GenServer with `Process.send_after`, and job execution with `Task.Supervisor`.

- **Pros:**
  - Zero library dependencies.

- **Cons:**
  - No persistence: in-flight jobs are lost on node crash or restart.
  - No built-in retry, backoff, or dead-letter semantics.
  - No observability without building a custom dashboard.
  - Duplicate job prevention (e.g., preventing two sync jobs for the same integration) requires manual implementation with database coordination.
  - Entirely redundant given Oban is already in the project.

### Option D: Exq (Redis-backed)

A Sidekiq-compatible job processor backed by Redis.

- **Pros:**
  - Mature ecosystem; familiar to developers from Ruby background.

- **Cons:**
  - Requires Redis, adding a third stateful service alongside PostgreSQL and the app. The caching strategy ADR explicitly rejected Redis to avoid this overhead.
  - No ACID guarantees across job storage and application data.
  - No meaningful Elixir community adoption over Oban for new projects.

## Decision

**Use Oban open-source (`~> 2.x`) as already adopted.** The project will not upgrade to Oban Pro at this stage. The open-source edition covers all specified use cases.

The following configuration and implementation choices formalize how Oban is used across the three worker types:

### Queue Design

Three queues with distinct concurrency limits reflecting their different resource profiles:

```elixir
config :metric_flow, Oban,
  repo: MetricFlow.Infrastructure.Repo,
  queues: [
    default: 10,
    sync: 5,
    correlations: 3
  ],
  plugins: [
    {Oban.Plugins.Pruner, max_age: 604_800},  # 7 days in seconds
    {Oban.Plugins.Lifeline, rescue_after: :timer.minutes(30)},
    {Oban.Plugins.Cron,
     crontab: [
       {"0 2 * * *", MetricFlow.DataSync.Scheduler, queue: :sync, max_attempts: 1}
     ]}
  ]
```

- `sync: 5` — network-bound API calls; 5 concurrent prevents excessive parallelism against rate-limited external APIs.
- `correlations: 3` — CPU-bound; kept low to avoid saturating the application node during daily post-sync calculations.
- `default: 10` — general-purpose tasks, including `RefreshMaterializedViewsWorker` (from the caching strategy ADR).

### Worker Configuration

**`DataSync.Scheduler`** (cron-invoked, enqueues `SyncWorker` jobs):

```elixir
use Oban.Worker,
  queue: :sync,
  max_attempts: 1
```

The scheduler must not retry — if it fails, the next daily cron will re-run. Retrying a partial scheduler run risks double-scheduling sync jobs.

**`DataSync.SyncWorker`** (external API calls, token refresh):

```elixir
use Oban.Worker,
  queue: :sync,
  max_attempts: 3,
  unique: [
    fields: [:args],
    keys: [:integration_id],
    period: 3_600,
    states: [:available, :scheduled, :executing]
  ]
```

Uniqueness on `integration_id` with a 1-hour period prevents duplicate syncs for the same integration during a scheduling window. `max_attempts: 3` with exponential backoff is appropriate for transient network failures; token expiry failures should be handled within `perform/1` (attempt refresh and return `{:error, :token_expired}` if refresh fails, allowing Oban to retry).

**`Correlations.CorrelationWorker`** (CPU-bound calculation):

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

Uniqueness on the correlation triple with a 24-hour period prevents recalculating the same pair multiple times in a single sync cycle.

### Error Handling Strategy

External API workers (`SyncWorker`) should use structured error returns rather than exceptions:

- Return `:ok` on full success.
- Return `{:error, reason}` on failure — Oban retries with exponential backoff.
- Return `{:snooze, seconds}` if a provider signals rate limiting (e.g., HTTP 429), delaying the job rather than burning a retry attempt.
- For unrecoverable errors (integration deleted, unsupported provider), the worker should log the error, update the `SyncJob` to `:failed` status, and return `{:error, reason}` to allow Oban to move the job to `discarded` state after max attempts.

The custom `backoff/1` callback can be implemented on `SyncWorker` to detect rate-limit errors and apply a longer delay:

```elixir
@impl Oban.Worker
def backoff(%Oban.Job{attempt: attempt, unsaved_error: %{reason: :rate_limited}}) do
  # Back off 5 minutes on rate limit errors regardless of attempt count
  300 + :rand.uniform(60)
end

def backoff(%Oban.Job{attempt: attempt}) do
  # Default exponential backoff
  trunc(:math.pow(attempt, 4)) + 15 + :rand.uniform(30)
end
```

### Pruning Strategy

`Oban.Plugins.Pruner` with `max_age: 604_800` (7 days) retains completed and discarded job records long enough for debugging and audit purposes without unbounded table growth. This is appropriate given the daily sync volume: approximately `N_integrations` jobs per day, which will be in the hundreds at most for the foreseeable scale.

The `Lifeline` plugin with `rescue_after: :timer.minutes(30)` recovers jobs that entered `:executing` state but were never completed due to node crashes. Sync jobs that take longer than 30 minutes are genuinely stalled and should be retried.

### Oban Web Dashboard

`oban_web` (now Apache 2.0 licensed) can be added as a free dependency for job visibility in development and production. Mount it under the authenticated admin scope:

```elixir
# In router.ex, within an authenticated admin scope:
import Oban.Web.Router
oban_dashboard "/oban"
```

The decision to add `oban_web` to the dependency list is deferred to when monitoring becomes an operational need, since the test environment uses `:manual` mode and no jobs execute automatically.

### Testing Pattern

The test environment already sets `config :metric_flow, Oban, testing: :manual`, which stores enqueued jobs in the database without executing them. This is the correct mode for unit and integration tests.

Test modules that verify job enqueueing should add:

```elixir
use Oban.Testing, repo: MetricFlow.Infrastructure.Repo
```

This provides `assert_enqueued/1`, `refute_enqueued/1`, and `all_enqueued/1` helpers.

Test modules that verify worker behavior should use `perform_job/2` rather than calling `perform/1` directly, since `perform_job` correctly stringifies args and validates the worker contract:

```elixir
assert :ok = perform_job(MetricFlow.DataSync.SyncWorker, %{
  integration_id: integration.id,
  user_id: user.id,
  sync_job_id: sync_job.id
})
```

For tests that need to assert both that a job was enqueued and that the worker correctly executed it, use `Oban.Testing.with_testing_mode(:inline, fn -> ... end)` to temporarily switch to inline mode within the test body.

## Consequences

**Trade-offs accepted:**

- Oban Pro workflows are not used. Job chaining (`SyncWorker` -> `RefreshMaterializedViewsWorker` -> `CorrelationWorker`) is implemented by enqueueing child jobs from within `perform/1`. This is a standard Oban pattern and sufficient for the current design; it can be replaced with Pro workflows if the chain grows complex enough to warrant it.
- The `sync: 5` concurrency limit is a conservative starting point. If external API providers have different rate limit windows, per-provider queues (e.g., `google_sync: 3`, `facebook_sync: 2`) may be warranted once empirical rate limiting is observed in production.
- The `Lifeline` rescue window of 30 minutes means a sync job that genuinely runs for more than 30 minutes (unlikely but possible for large datasets) will be restarted and may produce duplicate `SyncHistory` records. The `SyncWorker` spec already handles this via idempotent metric persistence and a unique constraint should be added to the `sync_jobs` table once concurrent execution risk is confirmed.

**Follow-up actions needed:**

1. Update `config/config.exs` to add the `plugins` list (Pruner, Lifeline, Cron) to the existing Oban configuration block. The `queues` key should be expanded to include the `correlations: 3` queue.
2. Implement `MetricFlow.DataSync.Scheduler` as an Oban worker with `use Oban.Worker, queue: :sync, max_attempts: 1`. The cron plugin config above registers it at `0 2 * * *` UTC.
3. Implement `MetricFlow.DataSync.SyncWorker` with the uniqueness constraint on `integration_id` and the custom `backoff/1` callback for rate limiting.
4. Implement `MetricFlow.Correlations.CorrelationWorker` with the uniqueness constraint on `(account_id, metric_id, goal_metric_id)`.
5. Add an Oban migration for the `oban_jobs` table if it does not already exist. Run `mix ecto.migrate` to apply.
6. Add `use Oban.Testing, repo: MetricFlow.Infrastructure.Repo` to `test/support/data_case.ex` (or equivalent) so all data-layer tests have access to `assert_enqueued` and `perform_job`.
7. Evaluate adding `{:oban_web, "~> 2.11"}` once background jobs are running in a staging environment and operational visibility is needed.

**Impact on development workflow:**

- The `:manual` testing mode means no background jobs execute during `mix test` or `mix spex` runs. Tests that verify sync behavior must either use `perform_job` explicitly or switch to `:inline` mode within the test body using `with_testing_mode/2`.
- The `Oban.Plugins.Cron` configuration means the `Scheduler` cron entry is registered at application boot. In development, this will attempt to enqueue `Scheduler` jobs at 2am UTC. If this is undesirable during development, the cron plugin can be omitted from the dev environment configuration or the schedule set to a non-overlapping time.
- Worker modules belong to their respective bounded contexts (`MetricFlow.DataSync`, `MetricFlow.Correlations`). The Boundary library will enforce that `SyncWorker` and `CorrelationWorker` only call functions exposed by their declared dependencies. Workers must not call across context boundaries except through the declared public API.
