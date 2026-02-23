# Caching Strategy for Dashboard Metrics and Correlation Results

## Status

Proposed

## Context

MetricFlow is a Phoenix LiveView analytics platform that aggregates metrics from multiple external data
sources (Google Analytics, Google Ads, Facebook Ads, QuickBooks) and displays them on user-configured
dashboards. Several performance-sensitive workloads have been identified from the data model and
domain specifications:

**Dashboard metric queries** — `Metrics.query_time_series/3` and `Metrics.aggregate_metrics/3` run
aggregate SQL across potentially large time-windowed datasets every time a dashboard loads. Multiple
users within the same account view the same underlying data, meaning the same expensive query may
execute many times in parallel.

**Correlation analysis** — `Correlations` context computes Pearson coefficients across pairs of time
series. This is CPU-intensive and changes only when new sync data arrives (once daily per the
automated scheduler). Displaying stale-by-one-day results is acceptable.

**Canned dashboards** — Pre-built dashboards with fixed metric definitions are queried frequently
and represent a shared, account-scoped read pattern that is ideal for caching.

**API rate limiting** — External provider calls (Google, Facebook, QuickBooks) are made by Oban
workers in the `DataSync` context. Rate-limit windows mean repeat requests for the same resource
within a short window must be avoided.

The current stack is:

- Phoenix 1.8 / LiveView 1.1 on a single node (initial deployment target)
- PostgreSQL via Ecto, with Oban 2.x for background job processing
- Phoenix PubSub already in the supervision tree (`MetricFlow.PubSub`)
- `Req ~> 0.5` for HTTP client calls to external APIs
- No Redis, no external cache infrastructure

The decision is constrained to a single-node initial deployment. Multi-node concerns (horizontal
scaling, distributed cache coherence) are explicitly out of scope for now, with the expectation
that the strategy can evolve if the deployment topology changes.

## Options Considered

### Option A: No Explicit Cache — PostgreSQL Query Optimization Only

Rely entirely on PostgreSQL query planner, connection pooling (via Ecto's DBConnection pool),
and appropriate database indexes.

- **Pros:**
  - Zero additional dependencies or infrastructure
  - No cache invalidation logic to maintain
  - Always returns fresh data
  - Index strategy already required regardless of caching choice

- **Cons:**
  - `query_time_series` and `aggregate_metrics` are aggregate queries over potentially millions of
    rows; even with indexes they will be slow at scale
  - Correlation calculations are recomputed on every read, which is wasteful for results that change
    only once per day
  - Offers no protection against thundering-herd on popular dashboards (many users loading the same
    dashboard simultaneously)

**Verdict:** Insufficient for the compute-intensive queries the spec describes. Adequate only as a
baseline that all other options must complement with proper indexing.

### Option B: PostgreSQL Materialized Views for Aggregate Metrics

Use PostgreSQL `MATERIALIZED VIEW` to pre-aggregate dashboard metrics at the database level.
Refresh the views on a schedule (after each daily sync) using an Oban worker.

Example migration pattern:

```sql
CREATE MATERIALIZED VIEW daily_metrics_by_user AS
  SELECT
    user_id,
    metric_name,
    provider,
    date_trunc('day', recorded_at) AS day,
    SUM(value) AS total,
    AVG(value) AS average,
    MIN(value) AS minimum,
    MAX(value) AS maximum,
    COUNT(*) AS sample_count
  FROM metrics
  GROUP BY user_id, metric_name, provider, date_trunc('day', recorded_at);

CREATE UNIQUE INDEX ON daily_metrics_by_user (user_id, metric_name, provider, day);
```

Refresh via an Oban worker after `SyncWorker` completes:

```elixir
# In SyncWorker.perform/1, after successful sync:
Phoenix.PubSub.broadcast(MetricFlow.PubSub, "sync:#{user_id}", {:sync_completed, user_id})

# Separate Oban worker triggered by the broadcast or chained job:
defmodule MetricFlow.DataSync.RefreshMaterializedViewsWorker do
  use Oban.Worker, queue: :sync

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => _user_id}}) do
    Ecto.Adapters.SQL.query!(
      MetricFlow.Infrastructure.Repo,
      "REFRESH MATERIALIZED VIEW CONCURRENTLY daily_metrics_by_user",
      []
    )
    :ok
  end
end
```

- **Pros:**
  - Pre-aggregation happens in PostgreSQL — no application-layer cache invalidation logic
  - `REFRESH MATERIALIZED VIEW CONCURRENTLY` (requires a unique index) allows reads to continue
    during refresh with no lock
  - Query against the view is a simple indexed scan — sub-millisecond reads
  - Data isolation is enforced by the `user_id` column in the view — multi-tenancy is maintained
  - No new Hex dependencies
  - Survives application restarts without a warm-up period

- **Cons:**
  - Only suitable for pre-defined, stable aggregation shapes; ad-hoc or configurable queries cannot
    be materialized ahead of time
  - View definitions live in migration files; changing the aggregation logic requires a new migration
  - Concurrent refresh requires a unique index on all grouping columns; schema changes to the view
    require dropping and recreating the index
  - Does not help with correlation coefficients (computed in Elixir, not SQL) or raw time-series
    queries that vary by date range

**Verdict:** Strong fit for the canned dashboard aggregate stats use case. Poor fit for correlation
results or flexible date-range queries.

### Option C: ETS-Backed In-Process Cache via Cachex

Use [Cachex](https://hex.pm/packages/cachex) (v4.x, 16M+ total downloads, actively maintained as
of 2025) as an in-process ETS-backed key-value store with TTL expiration. Add Cachex to the
supervision tree and wrap the expensive context functions.

Cachex is backed by ETS with no serialization overhead. Benchmarks show ETS to be approximately
6x faster than Redis on read throughput for large objects, and a real-world migration from Redis to
ETS has demonstrated 40%+ CPU reductions at peak load.

```elixir
# In application.ex, add to children:
{Cachex, name: :metric_cache}

# In Metrics context, wrap expensive queries:
def query_time_series(%Scope{} = scope, metric_name, opts \\ []) do
  cache_key = {"time_series", scope.user.id, metric_name, opts}
  Cachex.fetch(:metric_cache, cache_key, fn _key ->
    result = MetricRepository.query_time_series(scope, metric_name, opts)
    {:commit, result}
  end, expire: :timer.minutes(60))
end

# In Correlations context:
def get_correlation_results(%Scope{} = scope) do
  cache_key = {"correlations", scope.user.id}
  Cachex.fetch(:metric_cache, cache_key, fn _key ->
    result = CorrelationsRepository.list_results(scope)
    {:commit, result}
  end, expire: :timer.hours(25))
end
```

Cache invalidation after sync completion, using Phoenix PubSub already in the supervision tree:

```elixir
# In SyncWorker, after successful sync:
Phoenix.PubSub.broadcast(MetricFlow.PubSub, "sync:completed", {:cache_invalidate, user_id})

# In a CacheInvalidator GenServer subscribed to MetricFlow.PubSub:
def handle_info({:cache_invalidate, user_id}, state) do
  Cachex.del(:metric_cache, {"time_series", user_id})
  Cachex.del(:metric_cache, {"correlations", user_id})
  {:noreply, state}
end
```

For broader key-pattern invalidation (all keys for a user), Cachex supports streaming with a filter:

```elixir
def invalidate_user_cache(user_id) do
  Cachex.stream!(:metric_cache)
  |> Stream.filter(fn {_key, {k, _}} -> match?({_, ^user_id, _, _}, k) end)
  |> Enum.each(fn {key, _} -> Cachex.del(:metric_cache, key) end)
end
```

- **Pros:**
  - No external infrastructure — cache lives in the same BEAM process as the application
  - TTL-based expiration handles time-sensitive data without explicit invalidation for most cases
  - `Cachex.fetch/4` provides a read-through pattern: cache miss automatically populates the cache
  - Handles correlation results (computed in Elixir, not SQL) and flexible query results equally well
  - Fast: no serialization, no network round-trips; sub-microsecond lookups after the initial miss
  - Cache is scoped per user via the cache key — multi-tenant isolation maintained
  - 16M+ downloads, maintained by the same author since 2016, v4.1.1 released 2025

- **Cons:**
  - Cache is lost on application restart; every restart triggers a cold-start period with elevated
    database load until the cache warms up
  - On a single node this is fine; if the app ever scales to multiple nodes, ETS caches are
    per-node and will diverge unless coordinated via PubSub broadcasts to all nodes
  - Memory is bounded by the VM heap; a very large number of accounts with large metric histories
    could cause memory pressure without explicit size limits configured

**Verdict:** Best fit for computed/flexible query results, correlation caching, and any cache layer
that needs to survive the mismatch between SQL aggregation and Elixir-side computation.

### Option D: Redis via Redix

Add Redis as an external dependency and use `Redix` or a higher-level library for caching.

- **Pros:**
  - Cache persists across application restarts
  - Shared across multiple nodes naturally, making horizontal scaling straightforward
  - Rich data structures (sorted sets, hashes) can model some aggregation shapes directly
  - De facto standard for distributed caching

- **Cons:**
  - Adds an external infrastructure dependency (Redis server, connection management, TLS in prod)
  - Requires serialization/deserialization (`Jason.encode!/decode!` or `:erlang.term_to_binary`)
    on every cache read and write — benchmark data shows this is 6x slower than ETS
  - Introduces a new single point of failure; Redis downtime degrades or breaks cache reads
  - Oban already uses PostgreSQL for job storage; adding Redis adds a third stateful service to
    operate alongside PostgreSQL
  - Adds `Redix` or equivalent dependency plus operational overhead (connection pooling, health
    checks, monitoring) that provides no benefit on a single-node deployment
  - The project prompt explicitly identifies this as a cost concern: "adding Redis increases
    infrastructure complexity"

**Verdict:** Premature for a single-node deployment. The benefits materialize only when multiple
application nodes need a shared cache. Not adopted at this stage.

### Option E: ConCache

Use [ConCache](https://hex.pm/packages/con_cache), an older ETS-backed library with per-row TTL
support and row-level isolated writes.

- **Pros:**
  - Simple API, ETS-backed, single dependency
  - Per-row TTL is built in

- **Cons:**
  - Backed by multiple GenServer processes which introduces message-passing overhead absent in
    Cachex's design
  - Less actively developed than Cachex; Cachex was explicitly designed as a successor addressing
    ConCache's limitations
  - Smaller community and fewer features (no read-through `fetch`, no distributed adapters)

**Verdict:** Superseded by Cachex for new projects.

### Option F: Nebulex

Use [Nebulex](https://hex.pm/packages/nebulex), a multi-level distributed caching toolkit with
adapter-based backends.

- **Pros:**
  - Supports multi-level caches (e.g., local ETS L1 + Redis L2)
  - Declarative caching via `use Nebulex.Caching` macros (similar to Spring Cache)
  - Architecture-forward: designed to scale from single-node to distributed without code rewrites

- **Cons:**
  - Significantly more complex setup than Cachex for a use case that does not yet need distribution
  - The project does not need a distributed cache or a multi-level topology at launch
  - Smaller community and download count than Cachex on Hex.pm

**Verdict:** Viable as a future migration target if the app scales to multiple nodes, but over-
engineered for the initial single-node deployment.

## Decision

Adopt a **two-layer caching strategy**:

**Layer 1 — PostgreSQL Materialized Views** for pre-aggregated dashboard stats (Option B):

Create a `daily_metrics_by_user` materialized view that pre-aggregates `SUM`, `AVG`, `MIN`, `MAX`,
and `COUNT` by `(user_id, metric_name, provider, day)`. `Metrics.aggregate_metrics/3` and the
canned dashboard queries will read from this view rather than the raw `metrics` table. A unique
index on all grouping columns enables `REFRESH MATERIALIZED VIEW CONCURRENTLY`.

An Oban worker (`RefreshMaterializedViewsWorker`) will be enqueued by `SyncWorker` upon each
successful sync completion, keeping the view current without application restarts or warm-up periods.

**Layer 2 — Cachex** for computed results and flexible queries (Option C):

Add `{:cachex, "~> 4.1"}` to `mix.exs` and start `{Cachex, name: :metric_cache}` in
`MetricFlow.Application`. Wrap the following with Cachex read-through caching:

- `Metrics.query_time_series/3` — TTL of 60 minutes; invalidated by `SyncWorker` PubSub broadcast
- `Correlations` result listing — TTL of 25 hours (longer than the daily sync cycle); invalidated
  by PubSub broadcast after `CorrelationWorker` completes
- `Metrics.list_metric_names/2` — TTL of 60 minutes; used by the Goals UI and dashboard config

Cache keys must include `user_id` (from `Scope`) to maintain multi-tenant isolation. The PubSub
invalidation channel `"cache:invalidate"` will be subscribed to by a lightweight `GenServer` or
`Module`-level handler that calls `Cachex.del/2` for targeted keys or `Cachex.clear/1` scoped by
a key scan for all keys belonging to a given user.

**API response caching** is explicitly out of scope for this decision. The `DataSync` workers
already use Oban's unique job constraint and scheduling to prevent duplicate sync calls within a
window. If Req's built-in `cache: true` option (which uses `if-modified-since`) proves insufficient
against specific providers, a custom Req plugin with Cachex as the backing store can be added
incrementally.

**Redis is not adopted.** The single-node deployment has no need for a shared external cache, and
the infrastructure cost outweighs any benefit at this stage.

## Consequences

**Trade-offs accepted:**

- Cachex cache is lost on application restart, causing a brief cold-start period. This is acceptable
  for an initial deployment where dashboards re-warm within the first few user requests.
- Materialized view refresh is asynchronous; the view may lag behind a sync completion by the time
  it takes `RefreshMaterializedViewsWorker` to execute (typically seconds). This is acceptable given
  that syncs run daily and users tolerate stale-by-minutes data on aggregate stat cards.
- The materialized view covers a fixed aggregation shape. Ad-hoc queries against the raw `metrics`
  table will still require Cachex or direct SQL optimization.

**Follow-up actions needed:**

1. Add `{:cachex, "~> 4.1"}` to `mix.exs` and `{Cachex, name: :metric_cache}` to the supervision
   tree in `lib/metric_flow/application.ex`.
2. Write the `20260221_create_daily_metrics_materialized_view` Ecto migration with the view
   definition and unique index.
3. Implement `RefreshMaterializedViewsWorker` in `MetricFlow.DataSync` and enqueue it from
   `SyncWorker.perform/1` on success.
4. Add a `CacheInvalidator` module (lightweight GenServer or `handle_info` in a supervised process)
   that subscribes to `MetricFlow.PubSub` and calls `Cachex.del` on relevant keys.
5. Wrap `Metrics.query_time_series/3`, `Metrics.aggregate_metrics/3`, and `Metrics.list_metric_names/2`
   with `Cachex.fetch/4` calls using scoped cache keys.
6. Document the cache key naming convention (`{query_type, user_id, ...discriminators}`) so future
   contributors scope keys consistently and do not accidentally share data across tenants.

**Impact on development workflow:**

- Unit tests for `Metrics` and `Correlations` context functions should start the Cachex cache in
  `test/support/` and clear it between test cases to avoid inter-test contamination.
- The `Cachex` supervision tree entry should be guarded by environment so test runs can use a
  `:no_cache` or isolated named cache to prevent shared state.
- Materialized view queries require the view to exist in the test database; migration tooling
  handles this automatically since `mix test` runs `ecto.migrate`.
- If the deployment topology ever grows to multiple nodes (e.g., via Fly.io clustering), revisit
  this decision: the PubSub-driven cache invalidation pattern already broadcasts to all nodes if
  Phoenix PubSub is configured with a distributed adapter (`Phoenix.PubSub.PG2` or Redis adapter),
  making the Cachex layer multi-node compatible with a configuration-only change.
