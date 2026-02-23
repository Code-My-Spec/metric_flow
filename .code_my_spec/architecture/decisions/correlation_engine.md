# Correlation Engine: Approach for Computing Pearson Coefficients

## Status

Proposed

## Context

MetricFlow's `Correlations` context must compute Pearson correlation coefficients
between pairs of marketing time series (traffic, ad spend, conversions) and goal
metrics (revenue, signups). The `CorrelationResult` schema records
`coefficient`, `optimal_lag`, and `calculated_at` per metric pair.

**Lag detection** is a first-class requirement. The system must determine not just
whether two metrics are correlated, but whether one leads the other in time — for
example, whether ad spend predicts revenue 3 days later. This requires computing
the correlation at each candidate lag (e.g., -30 to +30 days) and selecting the
lag with the maximum absolute correlation. This is the time-lagged cross-
correlation (TLCC) technique.

**Scale parameters:**
- Series length: 30-365 data points (daily granularity from `query_time_series/3`)
- Pairs per job run: combinatorial — N marketing metrics x M goal metrics per
  account; typically dozens to a few hundred pairs
- Lag candidates per pair: up to 61 (-30..30 days)
- Execution context: background `CorrelationWorker` Oban job, not user-facing
- Cache TTL: 25 hours (decided in `caching_strategy.md`); results need not be
  recomputed more than once per day

The current dependency stack includes Ecto/PostgreSQL, Oban, Req, and Jason.
No numerical computing library is currently present.

The project is maintained by a small team. Dependencies should be chosen for
long-term maintainability and minimal operational overhead.

## Options Considered

### Option A: Pure Elixir with Enum

Implement the Pearson formula directly using `Enum.zip_reduce/4` over two float
lists. Lag detection is implemented by slicing lists with `Enum.drop/2` and
`Enum.take/2` and re-running the formula at each offset.

The algorithm is a single-pass deviation-from-mean approach that avoids
catastrophic cancellation and is numerically equivalent to reference
implementations.

- **Pros:**
  - Zero new dependencies
  - Any Elixir developer can read, audit, and modify the implementation
  - No compile-time toolchain requirements (no Rust, no XLA binaries)
  - Easy to unit test with plain `ExUnit.Case`
  - Full float64 precision; identical accuracy to all other options

- **Cons:**
  - Elixir list operations allocate intermediate lists; at 300 pairs x 61 lags x
    365-element series, worst-case runtime is in the range of 15-60 seconds per
    job on typical hardware
  - If account sizes grow significantly (thousands of metric pairs), this approach
    will not scale without switching strategies

**Performance analysis:** Each pair+lag requires one pass over up to 365 elements
via `Enum.zip_reduce/4`. At 300 pairs * 61 lags, there are ~18,300 passes. At
roughly 10 million element-operations per second in pure Elixir, worst-case
execution time is ~67 seconds. Since the job runs in a background worker with a
25-hour cache TTL, this is tolerable. `Task.async_stream/3` can parallelize
across pairs using all available schedulers, reducing wall-clock time by a factor
of `System.schedulers_online()` (typically 4-16 on hosted infrastructure).

### Option B: PostgreSQL corr() and Self-Join CTEs

Use PostgreSQL's native `corr(y, x)` aggregate function with a CTE-based self-
join to shift one series by lag intervals via `recorded_at + (lag * INTERVAL '1 day')`.

- **Pros:**
  - No new dependencies; uses existing PostgreSQL connection
  - PostgreSQL's `corr()` is a correct, battle-tested aggregate function
  - Runs entirely inside the database

- **Cons:**
  - Lag detection requires a multi-CTE query with a `generate_series(-30, 30)` cross
    join against the metrics table — a complex SQL construct that is difficult to
    unit test, type-check, or reason about in isolation
  - Executing hundreds of self-join correlation queries adds significant read
    pressure to the `metrics` table, competing with user-facing dashboard queries
  - Query construction (embedding lag range, metric names, and user_id) requires
    dynamic SQL strings or fragile Ecto fragment composition
  - The `CorrelationWorker` already exists to move CPU-intensive work off the
    request path; pushing the work back into PostgreSQL negates this design intent
  - Cannot benefit from BEAM parallelism via `Task.async_stream`

### Option C: Nx (Numerical Elixir)

Use the `nx` package for tensor-based computation. Pearson r is assembled from
`Nx.mean/1`, `Nx.standard_deviation/1`, and arithmetic tensor ops. Lag detection
uses `Nx.slice/3`.

- **Pros:**
  - Tensor operations are faster than Elixir lists for large arrays
  - Actively maintained by the Elixir core team; 1.23M downloads, v0.11.0
    released February 2026
  - Can compile to GPU via EXLA for very large datasets

- **Cons:**
  - Nx does not provide a built-in Pearson correlation function; it must be
    assembled manually, making implementation complexity equivalent to Option A
    with added tensor semantics to learn
  - For series of 30-365 points, tensor allocation and BEAM binary interop
    overhead dominates actual computation; Nx is not faster than pure Elixir at
    these small sizes
  - The EXLA backend (which provides the large performance gains) adds ~500MB of
    XLA precompiled binaries to the deployment, requires matching binary to
    OS/arch, and adds significant cold-start JIT compilation overhead
  - Using the default BinaryBackend (no EXLA), Nx is 2-5x faster than pure
    Elixir at best for small arrays — not a meaningful difference for a background job

### Option D: Explorer (Elixir Dataframes on Polars)

Use `Explorer.Series.correlation/3` which dispatches to Polars' `pearson_corr`
Rust implementation via a precompiled NIF binary. Lag detection uses
`Series.head/2` and `Series.tail/2` as constant-time slice operations.

- **Pros:**
  - `Series.correlation(s1, s2, method: :pearson)` is a single function call
    with no manual formula implementation
  - 5-20x faster than pure Elixir for series operations; uses Polars' numerically
    stable single-pass algorithm
  - Ships precompiled NIF binaries for Linux x86_64/ARM64, macOS x86_64/ARM64,
    Windows x86_64 via RustlerPrecompiled — no Rust toolchain needed in CI or
    production deployments
  - Actively maintained (v0.11.1 August 2025, v0.11.0 July 2025) under the
    `elixir-nx` organization with multiple active owners; 767K downloads
  - `Series.head/2` and `Series.tail/2` are O(1) offset operations in Polars —
    no buffer copies during lag iteration
  - Can be swapped in as a drop-in replacement inside the `Math` module without
    changing the public API or worker logic

- **Cons:**
  - Adds a dependency (~15MB precompiled NIF binary)
  - Introduces a Rust NIF boundary — NIF crashes can bring down the BEAM node
    (though Polars is mature and this risk is low in practice)
  - For the current scale (30-365 points), the performance advantage over pure
    Elixir is measurable but not critical for a background job

### Option E: Statistics Hex Package

Use `Statistics.correlation/2` from the `statistics` package.

- **Pros:**
  - Single function call for the zero-lag case

- **Cons:**
  - Package had a near four-year development gap (v0.6.2 in 2019, v0.6.3 in 2023);
    essentially abandoned
  - Does not provide lag detection — same manual loop as Option A is still required
  - Pure Elixir performance identical to Option A
  - Adds a stale dependency for zero capability gain over Option A

### Option F: Custom Rustler NIF

Write a custom Rust NIF using `rustler` to implement Pearson correlation and the
full lag sweep in a single native function.

- **Pros:**
  - Maximum possible performance
  - Entire lag sweep can be done in one NIF call, minimizing BEAM/NIF boundary crossings

- **Cons:**
  - Introduces Rust as a second language to the codebase; requires Rust expertise
    for ongoing maintenance
  - NIF development and cross-compilation in CI is significantly more complex than
    any other option
  - Provides no meaningful advantage over Explorer/Polars for this dataset size
  - A small team should not own and maintain native code for a problem already
    solved by a well-maintained upstream library

## Decision

Adopt **Option A (Pure Elixir) as the initial implementation**, with a documented
upgrade path to **Option D (Explorer)** if the background job runtime becomes a
concern.

**Rationale:**

The correlation job is a background Oban worker with a 25-hour cache TTL. It does
not affect user-facing latency. The pure Elixir implementation is readable,
dependency-free, and unit-testable without any setup. For 30-365 data points
across hundreds of pairs, it completes within a few minutes even in the worst
case — well within the cache window. With `Task.async_stream/3` parallelism
across pairs, wall-clock time on a modern deployment instance (4-8 schedulers)
is reduced by 4-8x.

Explorer is the right upgrade target because it requires only:
1. Adding `{:explorer, "~> 0.11"}` to `mix.exs`
2. Swapping the internals of the `Math` module (3-4 lines per function)

The public interface (`Math.pearson/2`, `Math.cross_correlate/3`,
`Math.extract_values/1`) remains unchanged. No changes to `CorrelationWorker`,
tests, or the `Correlations` context are needed.

PostgreSQL's `corr()` function is rejected because it pushes CPU-intensive work
back into the database, adds join pressure to the `metrics` table, and produces
query code that is difficult to test and maintain. Nx is rejected because it does
not have a built-in Pearson function and provides no performance benefit at small
series sizes without EXLA, which carries a 500MB deployment overhead. The
`statistics` package is rejected because it is essentially unmaintained and offers
nothing beyond Option A. A custom Rustler NIF is rejected as over-engineering when
Explorer provides equivalent performance via a maintained upstream library.

## Consequences

**Trade-offs accepted:**

- The initial pure Elixir implementation may take 15-60 seconds per job run at
  worst-case scale (365-day window, hundreds of metric pairs, 61-lag sweep).
  This is acceptable because the job runs in the background with a 25-hour TTL.
  If job duration becomes a concern, it is diagnosed via Oban telemetry and
  addressed with an Explorer migration (see upgrade path above).

- Pure Elixir list operations allocate intermediate lists. For the expected dataset
  sizes, BEAM garbage collection handles this without memory pressure. If metric
  series grow to thousands of data points per day (e.g., hourly granularity),
  Explorer's zero-copy slice operations become important.

**Follow-up actions needed:**

1. Create `lib/metric_flow/correlations/math.ex` with `pearson/2`,
   `cross_correlate/3`, and `extract_values/1` as documented in
   `docs/knowledge/correlation_engine/implementation_patterns.md`.

2. Implement `MetricFlow.Correlations.CorrelationWorker` using
   `Task.async_stream/3` to parallelize pair-wise computations.

3. Add `mix test test/metric_flow/correlations/math_test.exs` unit tests that
   verify Pearson accuracy (perfect correlation = 1.0, anti-correlation = -1.0,
   zero-variance = nil) and lag detection (known-lagged series returns correct
   optimal lag).

4. Add Oban telemetry logging in `CorrelationWorker.perform/1` to record job
   duration and number of pairs computed. If p95 duration exceeds 120 seconds,
   trigger the Explorer migration.

5. **Explorer migration trigger:** If telemetry shows job duration is a concern,
   add `{:explorer, "~> 0.11"}` to `mix.exs` and swap the `Math` module internals
   per the pattern in `docs/knowledge/correlation_engine/implementation_patterns.md`.
   No other changes are needed.

**Impact on development workflow:**

- The `Math` module is pure functional code with no database or process
  dependencies. Unit tests run with `mix test test/metric_flow/correlations/math_test.exs`
  at full speed without sandbox setup.

- `CorrelationWorker` tests use `Oban.Testing` helpers and require the standard
  test database setup, but the statistical computation is isolated in `Math` and
  not re-tested at the worker level.

- If Explorer is adopted, the NIF binary is downloaded by `mix deps.get` and
  added to `.gitignore`. No additional CI steps are required. The `EXPLORER_BUILD=1`
  environment variable enables source compilation from Rust if precompiled binaries
  are unavailable for the target platform (e.g., uncommon Linux distributions).
