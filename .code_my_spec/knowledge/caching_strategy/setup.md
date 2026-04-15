# Caching Strategy: Setup and Implementation Guide

This document covers every practical step for implementing MetricFlow's two-layer caching strategy
as decided in `docs/architecture/decisions/caching_strategy.md`. The two layers are:

- **Layer 1 — PostgreSQL Materialized Views**: pre-aggregated dashboard stats that survive restarts
- **Layer 2 — Cachex**: in-process ETS-backed cache for computed results and flexible queries

---

## Table of Contents

1. [Adding Cachex to the Project](#1-adding-cachex-to-the-project)
2. [Supervision Tree Configuration](#2-supervision-tree-configuration)
3. [Cache Key Naming Conventions](#3-cache-key-naming-conventions)
4. [Read-Through Caching with Cachex.fetch/4](#4-read-through-caching-with-cachexfetch4)
5. [PubSub-Based Cache Invalidation](#5-pubsub-based-cache-invalidation)
6. [PostgreSQL Materialized View Setup](#6-postgresql-materialized-view-setup)
7. [Refreshing the Materialized View After Sync](#7-refreshing-the-materialized-view-after-sync)
8. [Testing Patterns](#8-testing-patterns)

---

## 1. Adding Cachex to the Project

Add the dependency to `mix.exs`. Cachex v4.x uses ETS directly without GenServer message-passing
overhead, making it the fastest in-process option on the BEAM.

```elixir
# mix.exs
defp deps do
  [
    # ... existing deps ...
    {:cachex, "~> 4.1"}
  ]
end
```

Run `mix deps.get` to fetch.

---

## 2. Supervision Tree Configuration

Start a single named Cachex instance in the application supervision tree. One cache instance
named `:metric_cache` holds all MetricFlow cache entries; namespacing is achieved through
structured cache keys (see section 3) rather than multiple cache instances.

Place the Cachex child **after** `Phoenix.PubSub` and **before** `MetricFlowWeb.Endpoint`
so that PubSub is available when the `CacheInvalidator` subscribes, and the cache is ready
before any web requests arrive.

```elixir
# lib/metric_flow/application.ex
defmodule MetricFlow.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      MetricFlowWeb.Telemetry,
      MetricFlow.Infrastructure.Repo,
      MetricFlow.Infrastructure.Vault,
      {DNSCluster, query: Application.get_env(:metric_flow, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: MetricFlow.PubSub},
      {Oban, Application.fetch_env!(:metric_flow, Oban)},
      # Layer 2 cache — must start after PubSub, before Endpoint
      cache_spec(),
      MetricFlow.Cache.CacheInvalidator,
      MetricFlowWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: MetricFlow.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Guard the Cachex child spec by environment. In test we use a separate
  # named cache per test module (see section 8). In dev and prod we use the
  # shared :metric_cache instance.
  defp cache_spec do
    case Application.get_env(:metric_flow, :cache_name, :metric_cache) do
      :disabled -> []
      name -> {Cachex, name: name}
    end
  end
end
```

If you prefer not to add a config key, a simpler pattern is to always start Cachex but vary
the name in test via `start_supervised!/1`:

```elixir
# Simpler variant — always start the cache in application.ex:
{Cachex, name: :metric_cache}
```

Then in test setup call `Cachex.clear(:metric_cache)` between tests rather than starting a
fresh instance (see section 8 for the full test pattern).

---

## 3. Cache Key Naming Conventions

Every cache key must be a **tuple whose second element is `user_id`**. This is the primary
multi-tenancy invariant: no cache entry may be read by a user who did not create it.

### Convention

```
{query_type :: String.t(), user_id :: integer(), discriminators...}
```

Where `discriminators` are additional atoms, strings, or serialisable values that distinguish
variants of the same query type.

### Registered Keys

| Context function | Cache key pattern | TTL | Invalidation trigger |
|---|---|---|---|
| `Metrics.query_time_series/3` | `{"time_series", user_id, metric_name, date_range}` | 60 min | `SyncWorker` PubSub broadcast |
| `Metrics.aggregate_metrics/3` | `{"aggregate", user_id, metric_name, provider, period}` | 60 min | `SyncWorker` PubSub broadcast |
| `Metrics.list_metric_names/2` | `{"metric_names", user_id, opts_hash}` | 60 min | `SyncWorker` PubSub broadcast |
| `Correlations` result listing | `{"correlations", user_id}` | 25 hours | `CorrelationWorker` PubSub broadcast |

### Key Construction Helpers

Place these helpers in a `MetricFlow.Cache` module to centralise key building and prevent
drift between the caching call-site and the invalidation call-site:

```elixir
# lib/metric_flow/cache.ex
defmodule MetricFlow.Cache do
  @moduledoc """
  Cache key constructors and invalidation helpers for :metric_cache.

  All keys are user-scoped tuples. The second element is always the
  integer user_id from a MetricFlow.Users.Scope struct.

  ## Key convention

      {query_type :: String.t(), user_id :: integer(), discriminators...}

  Never share a key across users. Always derive the key from scope.user.id.
  """

  @cache :metric_cache

  # --- Key constructors ---

  def time_series_key(user_id, metric_name, opts),
    do: {"time_series", user_id, metric_name, normalise_opts(opts)}

  def aggregate_key(user_id, metric_name, provider, period),
    do: {"aggregate", user_id, metric_name, provider, period}

  def metric_names_key(user_id, opts),
    do: {"metric_names", user_id, normalise_opts(opts)}

  def correlations_key(user_id),
    do: {"correlations", user_id}

  # --- Invalidation ---

  @doc """
  Deletes all cache entries for the given user_id.

  Streams the full ETS table and removes entries whose second tuple element
  matches user_id. Called by CacheInvalidator after a sync completes.
  """
  def invalidate_user(user_id) do
    @cache
    |> Cachex.stream!()
    |> Stream.filter(fn {:entry, key, _touched, _ttl, _value} ->
      match?({_, ^user_id, _}, key) or match?({_, ^user_id}, key)
    end)
    |> Enum.each(fn {:entry, key, _touched, _ttl, _value} ->
      Cachex.del(@cache, key)
    end)
  end

  @doc """
  Deletes a specific key. Prefer invalidate_user/1 for post-sync invalidation.
  Use this for targeted invalidation when only one query type is stale.
  """
  def invalidate(key), do: Cachex.del(@cache, key)

  # --- Private ---

  # Normalise keyword-list opts into a canonical sorted form so that
  # query_time_series(scope, name, date_range: {d1, d2}) and
  # query_time_series(scope, name, date_range: {d1, d2}, foo: :bar)
  # do not accidentally share a cache entry.
  defp normalise_opts(opts) when is_list(opts), do: Enum.sort(opts)
  defp normalise_opts(opts), do: opts
end
```

### Why Tuples, Not Strings

String keys (e.g., `"time_series:42:sessions:2025-01-01"`) require serialisation and are
prone to formatting bugs — for example, omitting a discriminator produces a collision
between two different queries. Tuple keys are compared structurally by the BEAM's pattern
matcher, making accidental collisions impossible when all discriminators are distinct
positional elements.

---

## 4. Read-Through Caching with Cachex.fetch/4

`Cachex.fetch/4` is the primary caching primitive. On a cache miss it calls the fallback
function, stores the result, and returns `{:commit, value}`. On a hit it returns
`{:ok, cached_value}` without calling the database.

### Signature

```elixir
Cachex.fetch(cache_name, key, fallback_fn, options)
# Returns {:commit, value} on miss (after storing), {:ok, value} on hit
```

### Wrapping Metrics.query_time_series/3

```elixir
# lib/metric_flow/metrics.ex
defmodule MetricFlow.Metrics do
  use Boundary, deps: [MetricFlow.Users, MetricFlow.Infrastructure, MetricFlow.Cache], exports: []

  alias MetricFlow.Cache
  alias MetricFlow.Users.Scope

  @doc """
  Returns a list of %{date: Date.t(), value: float()} maps for the given
  metric over the requested date range.

  Results are cached per-user for 60 minutes, keyed on metric_name and
  the normalised opts. The cache is invalidated by SyncWorker upon
  successful sync completion.
  """
  @spec query_time_series(Scope.t(), String.t(), keyword()) :: [map()]
  def query_time_series(%Scope{} = scope, metric_name, opts \\ []) do
    key = Cache.time_series_key(scope.user.id, metric_name, opts)

    case Cachex.fetch(:metric_cache, key, fn _key ->
           result = MetricRepository.query_time_series(scope, metric_name, opts)
           {:commit, result}
         end, expire: :timer.minutes(60)) do
      {:ok, value} -> value
      {:commit, value} -> value
    end
  end

  @doc """
  Returns aggregated stats (sum, avg, min, max, count) for the given metric,
  reading from the daily_metrics_by_user materialized view.

  Falls back to Cachex for ad-hoc queries that do not match the view's
  fixed aggregation shape.
  """
  @spec aggregate_metrics(Scope.t(), String.t(), keyword()) :: map()
  def aggregate_metrics(%Scope{} = scope, metric_name, opts \\ []) do
    provider = Keyword.get(opts, :provider)
    period = Keyword.get(opts, :period, :day)
    key = Cache.aggregate_key(scope.user.id, metric_name, provider, period)

    case Cachex.fetch(:metric_cache, key, fn _key ->
           result = MetricRepository.aggregate_metrics(scope, metric_name, opts)
           {:commit, result}
         end, expire: :timer.minutes(60)) do
      {:ok, value} -> value
      {:commit, value} -> value
    end
  end

  @doc """
  Lists distinct metric names available for the scoped user.
  Cached for 60 minutes — used by the Goals UI and dashboard config.
  """
  @spec list_metric_names(Scope.t(), keyword()) :: [String.t()]
  def list_metric_names(%Scope{} = scope, opts \\ []) do
    key = Cache.metric_names_key(scope.user.id, opts)

    case Cachex.fetch(:metric_cache, key, fn _key ->
           result = MetricRepository.list_metric_names(scope, opts)
           {:commit, result}
         end, expire: :timer.minutes(60)) do
      {:ok, value} -> value
      {:commit, value} -> value
    end
  end
end
```

### Wrapping Correlations Context

```elixir
# lib/metric_flow/correlations.ex (future context module)
defmodule MetricFlow.Correlations do
  use Boundary, deps: [MetricFlow.Users, MetricFlow.Infrastructure, MetricFlow.Cache], exports: []

  alias MetricFlow.Cache
  alias MetricFlow.Users.Scope

  @doc """
  Lists pre-computed correlation results for the scoped user.

  Cached for 25 hours — longer than the daily sync cycle so that results
  from a successful CorrelationWorker run persist through the following day.
  Invalidated by CorrelationWorker's PubSub broadcast on completion.
  """
  @spec list_results(Scope.t()) :: [map()]
  def list_results(%Scope{} = scope) do
    key = Cache.correlations_key(scope.user.id)

    case Cachex.fetch(:metric_cache, key, fn _key ->
           result = CorrelationsRepository.list_results(scope)
           {:commit, result}
         end, expire: :timer.hours(25)) do
      {:ok, value} -> value
      {:commit, value} -> value
    end
  end
end
```

### Cachex.fetch/4 Return Values

`Cachex.fetch/4` returns one of:

| Return | Meaning |
|---|---|
| `{:ok, value}` | Cache hit — value returned from ETS, fallback not called |
| `{:commit, value}` | Cache miss — fallback called, result stored, value returned |
| `{:ignore, value}` | Fallback returned `{:ignore, value}` — result not stored (useful for nil results you do not want to cache) |
| `{:error, reason}` | ETS or internal error |

To avoid caching errors or nils, the fallback can return `{:ignore, default}`:

```elixir
fn _key ->
  case MetricRepository.query_time_series(scope, metric_name, opts) do
    [] -> {:ignore, []}          # empty result — do not cache, retry next request
    result -> {:commit, result}  # non-empty — cache for 60 minutes
  end
end
```

---

## 5. PubSub-Based Cache Invalidation

Cache entries are invalidated after a sync completes using Phoenix PubSub, which is already
in the supervision tree as `MetricFlow.PubSub`.

### Invalidation Channel

All sync-completion events broadcast on `"cache:invalidate"` with a `{:invalidate_user, user_id}`
payload. This keeps the coupling between the broadcast source and the subscriber narrow —
the subscriber does not need to know which worker triggered the invalidation.

### CacheInvalidator GenServer

```elixir
# lib/metric_flow/cache/cache_invalidator.ex
defmodule MetricFlow.Cache.CacheInvalidator do
  @moduledoc """
  Subscribes to MetricFlow.PubSub and clears Cachex entries when sync workers
  signal that a user's data has changed.

  Listens on the "cache:invalidate" topic. Workers broadcast:

      Phoenix.PubSub.broadcast(MetricFlow.PubSub, "cache:invalidate", {:invalidate_user, user_id})

  This process then calls Cache.invalidate_user/1 to evict all entries for
  that user from :metric_cache.
  """

  use GenServer

  alias MetricFlow.Cache

  @topic "cache:invalidate"

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl GenServer
  def init(_opts) do
    Phoenix.PubSub.subscribe(MetricFlow.PubSub, @topic)
    {:ok, %{}}
  end

  @impl GenServer
  def handle_info({:invalidate_user, user_id}, state) do
    Cache.invalidate_user(user_id)
    {:noreply, state}
  end

  # Ignore unrecognised messages — future broadcast shapes will be added here
  def handle_info(_msg, state), do: {:noreply, state}
end
```

### Broadcasting from SyncWorker

```elixir
# lib/metric_flow/data_sync/sync_worker.ex (relevant excerpt)
defmodule MetricFlow.DataSync.SyncWorker do
  use Oban.Worker, queue: :sync, max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id, "integration_id" => integration_id}}) do
    # ... perform sync logic ...

    on_success(user_id)
    :ok
  end

  defp on_success(user_id) do
    # Invalidate the Cachex layer for this user
    Phoenix.PubSub.broadcast(
      MetricFlow.PubSub,
      "cache:invalidate",
      {:invalidate_user, user_id}
    )

    # Enqueue the materialized view refresh (Layer 1)
    %{user_id: user_id}
    |> MetricFlow.DataSync.RefreshMaterializedViewsWorker.new()
    |> Oban.insert()
  end
end
```

### Broadcasting from CorrelationWorker

```elixir
# lib/metric_flow/correlations/correlation_worker.ex (relevant excerpt)
defp on_success(user_id) do
  # Only the correlations key needs to be invalidated here; metric_names and
  # time_series were already invalidated by SyncWorker earlier in the pipeline.
  Phoenix.PubSub.broadcast(
    MetricFlow.PubSub,
    "cache:invalidate",
    {:invalidate_user, user_id}
  )
end
```

### Topic Design Notes

A single `"cache:invalidate"` topic is sufficient because the `CacheInvalidator` performs a
full user-scoped cache clear on every message. If finer-grained invalidation is ever needed
(e.g., invalidate only correlations but not time-series), introduce additional message shapes
handled in the `handle_info/2` clauses rather than adding separate topics.

Multi-node note: `Phoenix.PubSub` with the default `PG2` adapter broadcasts to all nodes in
the cluster. If the deployment is ever scaled to multiple nodes, the PubSub invalidation
broadcasts will automatically propagate to each node's `CacheInvalidator` without any code
changes. Each node clears its own ETS cache independently.

---

## 6. PostgreSQL Materialized View Setup

The materialized view pre-aggregates the `metrics` table by `(user_id, metric_name, provider, day)`.
Dashboard aggregate queries read from this view rather than the raw `metrics` table, reducing
query time from a full aggregate scan to a simple indexed lookup.

### Migration

```elixir
# priv/repo/migrations/20260221000000_create_daily_metrics_materialized_view.exs
defmodule MetricFlow.Infrastructure.Repo.Migrations.CreateDailyMetricsMaterializedView do
  use Ecto.Migration

  def up do
    # The materialized view itself
    execute("""
    CREATE MATERIALIZED VIEW daily_metrics_by_user AS
      SELECT
        user_id,
        metric_name,
        provider,
        date_trunc('day', recorded_at) AS day,
        SUM(value)   AS total,
        AVG(value)   AS average,
        MIN(value)   AS minimum,
        MAX(value)   AS maximum,
        COUNT(*)     AS sample_count
      FROM metrics
      GROUP BY
        user_id,
        metric_name,
        provider,
        date_trunc('day', recorded_at)
    """)

    # UNIQUE index is required for REFRESH MATERIALIZED VIEW CONCURRENTLY.
    # Without it, concurrent refresh falls back to an exclusive lock that
    # blocks reads during refresh.
    execute("""
    CREATE UNIQUE INDEX daily_metrics_by_user_lookup_idx
      ON daily_metrics_by_user (user_id, metric_name, provider, day)
    """)
  end

  def down do
    execute("DROP MATERIALIZED VIEW IF EXISTS daily_metrics_by_user")
  end
end
```

### Reading from the View in Ecto

Ecto cannot use a materialized view through a normal schema `use Ecto.Schema` because views
do not have a primary key column by default. Use a schemaless query or a read-only embedded
schema with `@primary_key false`:

```elixir
# lib/metric_flow/metrics/daily_metric.ex
defmodule MetricFlow.Metrics.DailyMetric do
  @moduledoc """
  Read-only schema backed by the daily_metrics_by_user materialized view.
  Not a writable table — do not call Repo.insert or Repo.update on this schema.
  """
  use Ecto.Schema

  @primary_key false
  schema "daily_metrics_by_user" do
    field :user_id, :integer
    field :metric_name, :string
    field :provider, :string
    field :day, :utc_datetime
    field :total, :float
    field :average, :float
    field :minimum, :float
    field :maximum, :float
    field :sample_count, :integer
  end
end
```

```elixir
# In MetricFlow.Metrics.MetricRepository:
import Ecto.Query
alias MetricFlow.Metrics.DailyMetric
alias MetricFlow.Infrastructure.Repo

def aggregate_metrics(%Scope{} = scope, metric_name, opts) do
  provider = Keyword.get(opts, :provider)
  {start_date, end_date} = Keyword.get(opts, :date_range, default_date_range())

  DailyMetric
  |> where([m], m.user_id == ^scope.user.id)
  |> where([m], m.metric_name == ^metric_name)
  |> then(fn q ->
    if provider, do: where(q, [m], m.provider == ^provider), else: q
  end)
  |> where([m], m.day >= ^start_date and m.day <= ^end_date)
  |> select([m], %{
    day: m.day,
    total: m.total,
    average: m.average,
    minimum: m.minimum,
    maximum: m.maximum,
    sample_count: m.sample_count
  })
  |> order_by([m], asc: m.day)
  |> Repo.all()
end
```

### Concurrent Refresh Behaviour

`REFRESH MATERIALIZED VIEW CONCURRENTLY` builds a new version of the view in the background
and then swaps it in atomically. During the build phase, reads against the old view continue
without interruption. The unique index is the prerequisite — PostgreSQL uses it to reconcile
old and new rows.

Without `CONCURRENTLY`, the refresh takes an exclusive lock that blocks all reads for its
duration. Always use `CONCURRENTLY` in production.

### View Schema Changes

If the aggregation shape must change (e.g., add a `campaign_id` grouping column), the
migration must:

1. Drop the existing unique index.
2. Drop and recreate the materialized view.
3. Recreate the unique index on the new column set.

This means a `REFRESH MATERIALIZED VIEW CONCURRENTLY` is not possible on the first refresh
after the migration (there is no old data to swap against). The first refresh after a
migration will take an exclusive lock momentarily. Schedule migrations during low-traffic
windows.

---

## 7. Refreshing the Materialized View After Sync

The `RefreshMaterializedViewsWorker` Oban worker executes the `REFRESH` SQL and is enqueued
by `SyncWorker` after each successful sync. It runs in the `:sync` queue, which is already
configured in `config/config.exs`.

```elixir
# lib/metric_flow/data_sync/refresh_materialized_views_worker.ex
defmodule MetricFlow.DataSync.RefreshMaterializedViewsWorker do
  @moduledoc """
  Oban worker that refreshes the daily_metrics_by_user materialized view
  after a successful data sync.

  Enqueued by SyncWorker with the user_id that triggered the sync.
  The refresh operates on the entire view (not user-scoped), so multiple
  enqueue calls from different users within the same sync window will
  coalesce — see unique: options below.
  """

  use Oban.Worker,
    queue: :sync,
    max_attempts: 3,
    unique: [period: 60, keys: [], states: [:available, :executing]]
    # unique period: 60 seconds — if multiple syncs complete simultaneously,
    # only one refresh job is inserted. The single refresh covers all users
    # because the materialized view aggregates across all user_ids.

  alias MetricFlow.Infrastructure.Repo

  @view "daily_metrics_by_user"

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    Ecto.Adapters.SQL.query!(
      Repo,
      "REFRESH MATERIALIZED VIEW CONCURRENTLY #{@view}",
      []
    )

    :ok
  end
end
```

### Oban Unique Constraint Note

The `unique: [period: 60, keys: []]` option means Oban will deduplicate refresh jobs
inserted within a 60-second window regardless of their `args`. Since the refresh covers
all users (not a single user), there is no benefit to running it multiple times within
the same minute. If per-user views are ever introduced, change `keys: [:user_id]` to
deduplicate per user instead.

### Enqueueing from SyncWorker

```elixir
defp on_success(user_id) do
  # Enqueue the materialized view refresh — runs asynchronously in :sync queue
  %{}
  |> MetricFlow.DataSync.RefreshMaterializedViewsWorker.new()
  |> Oban.insert()

  # Invalidate Cachex for this user
  Phoenix.PubSub.broadcast(
    MetricFlow.PubSub,
    "cache:invalidate",
    {:invalidate_user, user_id}
  )
end
```

---

## 8. Testing Patterns

### Isolating the Cachex Cache in Tests

Cachex must be started in the test environment to exercise caching code paths. The cleanest
approach is to start a single named cache in `test/support/data_case.ex` (or `conn_case.ex`)
and clear it between tests.

```elixir
# test/support/data_case.ex
defmodule MetricFlowTest.DataCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      use Ecto.Schema
      import Ecto.Changeset
      import Ecto.Query
      import MetricFlowTest.DataCase
      alias MetricFlow.Infrastructure.Repo
    end
  end

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(MetricFlow.Infrastructure.Repo,
            shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)

    # Clear the cache between every test to prevent cross-test contamination
    if Process.whereis(:metric_cache) do
      Cachex.clear(:metric_cache)
    end

    :ok
  end
end
```

Start the cache once in `test/test_helper.exs`:

```elixir
# test/test_helper.exs
ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(MetricFlow.Infrastructure.Repo, :manual)

# Start the shared test cache. This is the same name used in production so
# that caching code paths execute as written without special test branches.
{:ok, _} = Cachex.start_link(name: :metric_cache)
```

### Testing Cache Hits and Misses

```elixir
defmodule MetricFlow.MetricsTest do
  use MetricFlowTest.DataCase

  alias MetricFlow.Metrics
  alias MetricFlow.Cache

  describe "query_time_series/3 caching" do
    test "caches result on first call and returns cached value on second call", %{scope: scope} do
      # First call — cache miss, hits the database
      result1 = Metrics.query_time_series(scope, "sessions")
      assert is_list(result1)

      # Verify the key is now in the cache
      key = Cache.time_series_key(scope.user.id, "sessions", [])
      assert {:ok, ^result1} = Cachex.get(:metric_cache, key)

      # Second call — cache hit, does not re-execute the query
      result2 = Metrics.query_time_series(scope, "sessions")
      assert result1 == result2
    end

    test "invalidate_user/1 clears all keys for the given user", %{scope: scope} do
      _result = Metrics.query_time_series(scope, "sessions")
      _result = Metrics.query_time_series(scope, "revenue")

      Cache.invalidate_user(scope.user.id)

      time_series_key = Cache.time_series_key(scope.user.id, "sessions", [])
      revenue_key = Cache.time_series_key(scope.user.id, "revenue", [])

      assert {:ok, nil} = Cachex.get(:metric_cache, time_series_key)
      assert {:ok, nil} = Cachex.get(:metric_cache, revenue_key)
    end

    test "does not share cache entries between users" do
      user1_scope = build_scope(user_id: 1)
      user2_scope = build_scope(user_id: 2)

      result1 = Metrics.query_time_series(user1_scope, "sessions")

      # Explicitly put a different value for user2 to confirm isolation
      key2 = Cache.time_series_key(2, "sessions", [])
      Cachex.put(:metric_cache, key2, [:different_data])

      assert Metrics.query_time_series(user1_scope, "sessions") == result1
      refute Metrics.query_time_series(user2_scope, "sessions") == result1
    end
  end
end
```

### Testing the CacheInvalidator

```elixir
defmodule MetricFlow.Cache.CacheInvalidatorTest do
  use MetricFlowTest.DataCase

  alias MetricFlow.Cache
  alias MetricFlow.Cache.CacheInvalidator

  test "invalidates user cache when broadcast is received" do
    user_id = 42

    # Seed the cache with a known entry
    key = Cache.time_series_key(user_id, "sessions", [])
    Cachex.put(:metric_cache, key, [%{date: ~D[2026-01-01], value: 100.0}])
    assert {:ok, [_entry]} = Cachex.get(:metric_cache, key)

    # Simulate the PubSub broadcast from SyncWorker
    Phoenix.PubSub.broadcast(MetricFlow.PubSub, "cache:invalidate", {:invalidate_user, user_id})

    # Give the GenServer time to process the message
    Process.sleep(10)

    assert {:ok, nil} = Cachex.get(:metric_cache, key)
  end
end
```

### Testing the Materialized View

The materialized view is created by `mix ecto.migrate`, which runs automatically in `mix test`.
Since the view is empty until the first `REFRESH`, test data must be inserted into the `metrics`
table and then the view must be refreshed explicitly in the test:

```elixir
setup do
  # Insert test metrics into the raw table
  insert_metrics(user_id: scope.user.id, metric_name: "sessions", value: 100.0)

  # Manually refresh the view so test queries against it return data
  Ecto.Adapters.SQL.query!(
    MetricFlow.Infrastructure.Repo,
    "REFRESH MATERIALIZED VIEW daily_metrics_by_user",
    []
  )

  :ok
end
```

Note: In tests, the sandbox pool holds an open transaction. `REFRESH MATERIALIZED VIEW` cannot
run inside a transaction on some PostgreSQL versions. If this causes issues, use
`@moduletag :skip_sandbox_transaction` and manage the database connection directly, or test
the repository function against the raw `metrics` table and write a separate integration test
for the view refresh worker.

---

## Summary Reference

| Component | Module | Location |
|---|---|---|
| Cache key builders and invalidation helpers | `MetricFlow.Cache` | `lib/metric_flow/cache.ex` |
| CacheInvalidator GenServer | `MetricFlow.Cache.CacheInvalidator` | `lib/metric_flow/cache/cache_invalidator.ex` |
| Cachex supervision tree entry | `MetricFlow.Application` | `lib/metric_flow/application.ex` |
| Metrics caching (fetch wraps) | `MetricFlow.Metrics` | `lib/metric_flow/metrics.ex` |
| Correlations caching (fetch wraps) | `MetricFlow.Correlations` | `lib/metric_flow/correlations.ex` |
| Materialized view read schema | `MetricFlow.Metrics.DailyMetric` | `lib/metric_flow/metrics/daily_metric.ex` |
| Materialized view migration | — | `priv/repo/migrations/20260221000000_create_daily_metrics_materialized_view.exs` |
| View refresh Oban worker | `MetricFlow.DataSync.RefreshMaterializedViewsWorker` | `lib/metric_flow/data_sync/refresh_materialized_views_worker.ex` |
