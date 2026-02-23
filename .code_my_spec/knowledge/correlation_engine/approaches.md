# Correlation Engine: Computing Pearson Coefficients in Elixir

This document surveys the available approaches for computing Pearson correlation
coefficients in MetricFlow's `Correlations` context, with specific attention to
lag detection (time-shifted correlations) and the scale requirements described
in the system spec.

## Problem Shape

The `CorrelationWorker` Oban job must compute Pearson r between pairs of time
series drawn from `Metrics.query_time_series/3`. Each series covers a 30-365 day
window, yielding roughly 30-365 float data points per series. The number of pairs
per account is combinatorial — N marketing metrics multiplied by M goal metrics —
so hundreds of pair-wise computations per job run are expected.

Lag detection means computing the correlation not just at offset 0, but at each
candidate lag (e.g., -30 to +30 days) and selecting the lag with the highest
absolute coefficient. This multiplies the per-pair computation by the number of
candidate lags tested.

The job runs as a background Oban worker. Latency is not a concern; throughput
and correctness are.

---

## Option A: Pure Elixir with Enum

### How it works

The Pearson formula is:

    r = sum((x - mean_x) * (y - mean_y)) / (n * std_x * std_y)

All components — means, deviations, products, standard deviations — can be
computed with a single or double pass over the two lists using `Enum.reduce/3`
or `Enum.zip_reduce/4`.

For lag detection, one series is shifted by slicing with `Enum.drop/2` or
`Enum.take/2` and the formula is re-run for each candidate offset.

### Sample implementation sketch

```elixir
defmodule MetricFlow.Correlations.Math do
  @doc """
  Pearson r for two equal-length float lists.
  Returns nil if either series has zero variance.
  """
  def pearson(xs, ys) when length(xs) == length(ys) and length(xs) > 1 do
    n = length(xs)
    mean_x = Enum.sum(xs) / n
    mean_y = Enum.sum(ys) / n

    {cov, var_x, var_y} =
      Enum.zip_reduce(xs, ys, {0.0, 0.0, 0.0}, fn x, y, {c, vx, vy} ->
        dx = x - mean_x
        dy = y - mean_y
        {c + dx * dy, vx + dx * dx, vy + dy * dy}
      end)

    denom = :math.sqrt(var_x * var_y)
    if denom == 0.0, do: nil, else: cov / denom
  end

  @doc """
  Cross-correlation across candidate lags.
  Returns {optimal_lag, max_coefficient}.
  lag_range is a Range, e.g. -30..30.
  """
  def cross_correlate(xs, ys, lag_range \\ -30..30) do
    lag_range
    |> Enum.map(fn lag ->
      {shifted_x, shifted_y} = align_for_lag(xs, ys, lag)
      r = pearson(shifted_x, shifted_y)
      {lag, r}
    end)
    |> Enum.filter(fn {_lag, r} -> not is_nil(r) end)
    |> Enum.max_by(fn {_lag, r} -> abs(r) end, fn -> {0, nil} end)
  end

  defp align_for_lag(xs, ys, lag) when lag > 0 do
    # positive lag: y leads x — drop first `lag` elements from y, trim x
    {Enum.take(xs, length(xs) - lag), Enum.drop(ys, lag)}
  end

  defp align_for_lag(xs, ys, lag) when lag < 0 do
    # negative lag: x leads y — drop first `|lag|` elements from x, trim y
    shift = abs(lag)
    {Enum.drop(xs, shift), Enum.take(ys, length(ys) - shift)}
  end

  defp align_for_lag(xs, ys, 0), do: {xs, ys}
end
```

### Assessment

| Criterion | Rating |
|-----------|--------|
| Implementation complexity | Low — standard library only |
| Dependency weight | Zero |
| Accuracy | Full float64 precision; identical to reference implementations |
| Performance (30-365 pts, 61-lag range) | Adequate. ~300 pairs x 61 lags = ~18k list scans of ≤365 elements each. In practice under 1 second per worker run on modern hardware. |
| Lag detection | Built-in with Enum.drop/take slicing |
| Maintainability | High — any Elixir developer can read and modify it |

**Key consideration:** At 365 data points and 61 lag candidates, each pair
requires about 61 list passes of ≤365 elements. Erlang's GC and list allocation
mean each pass allocates intermediate lists. For ~300 pairs, the rough operation
count is 300 * 61 * 365 * ~10 operations = ~670 million elementary operations.
Pure Elixir lists execute at roughly 10-50 million operations/second on typical
hardware, suggesting a worst-case run time of 13-67 seconds per job. Since Oban
runs this in a background worker with no user-facing latency, and results are
cached for 25 hours, this is likely acceptable — but borderline if account sizes
grow significantly.

Using `Enum.zip_reduce/4` (single-pass) and avoiding intermediate list allocation
(by keeping series as flat Elixir lists rather than maps) keeps the constant
factor small.

---

## Option B: PostgreSQL Statistical Functions

### How it works

PostgreSQL implements the ANSI SQL `corr()` aggregate function, which computes
the Pearson correlation coefficient natively in C. The function signature is:

    SELECT corr(y_value, x_value)
    FROM metrics
    WHERE user_id = $1 AND metric_name IN ($2, $3)
    GROUP BY metric_name

For lag detection, a self-join or CTE approach shifts one series by joining on
`date + interval '$lag days'`:

```sql
WITH lagged AS (
  SELECT
    m1.recorded_at,
    m1.value AS x_val,
    m2.value AS y_val,
    $lag AS lag_days
  FROM metrics m1
  JOIN metrics m2
    ON m2.user_id = m1.user_id
    AND m2.metric_name = $goal_metric
    AND m2.recorded_at = m1.recorded_at + ($lag * INTERVAL '1 day')
  WHERE m1.user_id = $1
    AND m1.metric_name = $metric
    AND m1.recorded_at BETWEEN $start AND $end
)
SELECT lag_days, corr(x_val, y_val) FROM lagged GROUP BY lag_days
```

To test all lags in one query, use `generate_series(-30, 30)` cross-joined with
the metrics data, then compute `corr()` grouped by lag. This is the approach
described in Max Halford's blog post on SQL cross-correlations.

### Assessment

| Criterion | Rating |
|-----------|--------|
| Implementation complexity | High — multi-CTE query required for lag sweep; verbose and hard to test |
| Dependency weight | Zero — uses existing PostgreSQL |
| Accuracy | PostgreSQL's corr() is numerically stable and correct |
| Performance (single pair) | Excellent for single-pair, single-lag queries |
| Performance (hundreds of pairs, full lag sweep) | Poor — each pair+lag requires a join against the full metrics table; hundreds of pairs with 61 lags = thousands of indexed scans or one very large cross-join |
| Lag detection | Possible but requires complex SQL construction |
| Maintainability | Low — SQL in Elixir strings is hard to unit-test, type-check, and refactor |

**Key consideration:** PostgreSQL's `corr()` is designed for aggregate correlation
across a table, not for repeated pair-wise correlation sweeps. Executing hundreds
of lag-shifted self-joins against the `metrics` table puts significant read load
on the database and competes with user-facing queries. The `CorrelationWorker` is
already a background job to avoid this kind of database pressure.

The pure SQL approach is well-suited for ad-hoc analysis or single-pair queries
but becomes an anti-pattern when used to replace an application-layer computation
engine at scale.

---

## Option C: Nx (Numerical Elixir)

### How it works

Nx provides multi-dimensional tensor operations with optional JIT compilation via
EXLA (Google's XLA) or Torchx backends. The Pearson formula translates directly
to tensor operations:

```elixir
defmodule MetricFlow.Correlations.NxMath do
  import Nx.Defn

  defn pearson(x, y) do
    n = Nx.size(x) |> Nx.as_type(:f64)
    mean_x = Nx.mean(x)
    mean_y = Nx.mean(y)
    dx = Nx.subtract(x, mean_x)
    dy = Nx.subtract(y, mean_y)
    cov = Nx.sum(Nx.multiply(dx, dy)) / n
    std_x = Nx.standard_deviation(x)
    std_y = Nx.standard_deviation(y)
    Nx.divide(cov, Nx.multiply(std_x, std_y))
  end
end
```

For lag detection, `Nx.slice/3` or tensor indexing efficiently shifts series
without list allocation.

### Package status (as of February 2026)

- **nx** v0.11.0 released February 19, 2026; 1.23M all-time downloads; 7,921
  downloads in last 7 days. Actively maintained by the Elixir core team.
- **exla** v0.10.0 released June 2025; 643K all-time downloads. EXLA is an
  optional compiler backend; it is not required for basic Nx usage.

### Assessment

| Criterion | Rating |
|-----------|--------|
| Implementation complexity | Medium — Nx API is clear but requires learning tensor semantics and `defn` compilation model |
| Dependency weight | Medium — `nx` alone is ~2MB compiled; EXLA adds ~500MB of XLA binaries if used |
| Accuracy | Full float64 precision with correct numerical algorithms |
| Performance (without EXLA) | 2-5x faster than pure Elixir for array ops; tensor allocation overhead dominates at small sizes (≤365 points) |
| Performance (with EXLA) | Potentially 100-1000x faster for large tensors; JIT compilation adds cold-start overhead on first call |
| Lag detection | Efficient — `Nx.slice` avoids list allocation |
| Maintainability | Medium — tensor code requires Nx familiarity; no runtime Rust dependency |

**Key consideration:** Nx's performance advantage materializes primarily at large
tensor sizes (thousands to millions of elements) or when using EXLA to compile
to GPU. For series of 30-365 points, tensor allocation and BEAM interop overhead
dominate the actual computation. Benchmarks show pure Elixir outperforms Nx for
small (< ~1000 element) arrays because the BEAM's overhead-per-element is lower
than Nx's binary tensor boxing overhead at those scales.

Additionally, Nx does not include a built-in Pearson correlation function; it
must be assembled from `Nx.mean`, `Nx.standard_deviation`, and arithmetic ops.
This means the implementation complexity of Option C is higher than Option A
while offering no measurable performance benefit at MetricFlow's dataset sizes.

EXLA is a large optional dependency (~500MB) that requires matching the XLA
precompiled binaries to the target OS/arch. This adds non-trivial CI and
deployment complexity. Without EXLA, Nx uses the BinaryBackend, which is slower
than optimized C code for small arrays.

---

## Option D: Explorer (Elixir Dataframes on Polars)

### How it works

Explorer wraps the Polars Rust library via Rustler precompiled NIFs. It provides
a `Series` type and a `DataFrame` type. `Explorer.Series.correlation/3` computes
Pearson or Spearman correlation directly:

```elixir
alias Explorer.Series

s1 = Series.from_list([1.0, 4.0, 7.0, 10.0])
s2 = Series.from_list([2.0, 5.0, 6.0, 11.0])
Series.correlation(s1, s2, method: :pearson)
# => 0.9912407071619304
```

For lag detection, series slicing uses `Series.slice/2` or `Series.head/2` /
`Series.tail/2`:

```elixir
def cross_correlate(xs, ys, lag_range \\ -30..30) do
  n = Series.size(xs)

  lag_range
  |> Enum.map(fn lag ->
    {sx, sy} =
      if lag > 0 do
        {Series.head(xs, n - lag), Series.tail(ys, n - lag)}
      else
        shift = abs(lag)
        {Series.tail(xs, n - shift), Series.head(ys, n - shift)}
      end

    r = Series.correlation(sx, sy, method: :pearson)
    {lag, r}
  end)
  |> Enum.max_by(fn {_lag, r} -> abs(r || 0.0) end, fn -> {0, nil} end)
end
```

### Package status (as of February 2026)

- **explorer** v0.11.1 released August 17, 2025; 767K all-time downloads.
  Active — v0.11.0 and v0.11.1 both released in mid-2025. Under the
  `elixir-nx` GitHub organization with multiple active maintainers.
- Ships **precompiled NIF binaries** for Linux x86_64, Linux ARM64, macOS x86_64,
  macOS ARM64, and Windows x86_64 via RustlerPrecompiled. No Rust toolchain
  required for standard installs. `EXPLORER_BUILD=1` env var enables local
  compilation from source if needed.

### Assessment

| Criterion | Rating |
|-----------|--------|
| Implementation complexity | Low — `Series.correlation/3` is a single function call |
| Dependency weight | Medium — ~15MB precompiled NIF binary; no Rust toolchain needed for deployment |
| Accuracy | Polars uses numerically stable Welford-style algorithms; identical results to reference implementations |
| Performance (30-365 pts) | 5-20x faster than pure Elixir for series operations; NIF call overhead is constant (~5-15 µs) and negligible for 61-lag sweeps |
| Performance (hundreds of pairs, full lag sweep) | Consistently fast — Polars C code handles the inner loop; `Series.slice` is O(1) via offset without copying |
| Lag detection | Natural — `Series.head/2` and `Series.tail/2` are constant-time slice operations over Polars chunked arrays |
| Maintainability | High — single idiomatic function call; precompiled binary removes Rust build toolchain from CI/CD |

**Key consideration:** Explorer's `Series.correlation/3` dispatches directly to
Polars' `pearson_corr` implementation in Rust, which uses a numerically stable
single-pass algorithm. The NIF call overhead (~10 µs) is negligible across 300
pairs * 61 lags = ~18,300 calls (total overhead ~183 ms), and the inner
computation per call is far faster than Elixir list reduction.

Explorer ships precompiled binaries for all major targets, meaning adding
`{:explorer, "~> 0.11"}` to `mix.exs` is the only step required in CI/CD and
production deployments. No Rust toolchain is needed.

Explorer is actively maintained under the same `elixir-nx` umbrella as Nx,
with frequent releases and multiple owners.

---

## Option E: Statistics Hex Package

### How it works

The `statistics` package provides `Statistics.correlation(x, y)` which computes
the Pearson product-moment correlation coefficient from two Elixir lists.

```elixir
Statistics.correlation([1, 2, 3], [4, 5, 6])
# => 1.0
```

### Package status (as of February 2026)

- **statistics** v0.6.3 released December 2023; 1.24M all-time downloads
  (mostly historical); ~78 downloads per day, indicating very low current usage.
- Previous release (v0.6.2) was November 2019 — a near four-year gap before the
  2023 patch. Development is essentially frozen.
- 141 GitHub stars, minimal community activity.

### Assessment

| Criterion | Rating |
|-----------|--------|
| Implementation complexity | Very low — single function call |
| Dependency weight | Minimal — pure Elixir |
| Accuracy | Correct for basic cases; no documented edge case handling for zero-variance series |
| Performance | Similar to Option A (pure Elixir lists); no measurable advantage |
| Lag detection | Not provided — must be built manually with same logic as Option A |
| Maintainability | Poor — nearly abandoned; no Elixir Forum presence or recent community discussion |

**Key consideration:** `Statistics.correlation/2` provides no capability beyond
what a hand-rolled implementation offers (Option A), while adding a dependency
on a package that was inactive for four years. If the package were abandoned
entirely and a security issue found in Elixir's own standard library interaction,
there would be no recourse. The pure Elixir option (A) is strictly preferable to
taking this dependency.

---

## Option F: Rustler NIF

### How it works

Write a custom Rust NIF using the `rustler` package to implement Pearson
correlation (and optionally the full lag sweep) in native code. The NIF is
compiled into a shared library loaded by the BEAM at startup.

```elixir
defmodule MetricFlow.Correlations.NativeMath do
  use Rustler, otp_app: :metric_flow, crate: "correlation_math"

  def pearson(_xs, _ys), do: :erlang.nif_error(:nif_not_loaded)
  def cross_correlate(_xs, _ys, _max_lag), do: :erlang.nif_error(:nif_not_loaded)
end
```

### Assessment

| Criterion | Rating |
|-----------|--------|
| Implementation complexity | High — requires Rust toolchain, CI cross-compilation, NIF safety considerations |
| Dependency weight | `rustler` + Rust toolchain in CI; ~500KB compiled NIF |
| Accuracy | Identical to any float64 implementation |
| Performance | Maximum native performance; effectively equivalent to Explorer's Polars backend for this use case |
| Lag detection | Can implement the full sweep in a single NIF call, minimizing round-trips |
| Maintainability | Low for a small team — requires Rust expertise; adds a second language to the codebase |

**Key consideration:** A custom Rustler NIF is the highest-performance option
but carries the highest maintenance burden. The team would own the Rust code
indefinitely, including ensuring the NIF is marked dirty for long-running
computations to avoid blocking the BEAM scheduler. For a problem where Explorer
provides essentially the same performance profile using battle-tested Polars code
maintained by an active open-source community, writing a custom NIF is
over-engineering.

---

## Summary Comparison

| Option | Zero-lag r | Lag detection | Zero deps added | Maintainability | Active maintenance |
|--------|-----------|---------------|-----------------|-----------------|-------------------|
| A: Pure Elixir | Manual, correct | Manual, adequate | Yes | High | N/A |
| B: PostgreSQL corr() | Native, fast | Complex SQL | Yes | Low | N/A |
| C: Nx | Manual (no built-in r) | Efficient slicing | No (Nx) | Medium | Yes |
| D: Explorer | One function call | head/tail slicing | No (Explorer) | High | Yes |
| E: Statistics pkg | One function call | Not provided | No (stale dep) | Poor | No |
| F: Rustler NIF | Maximum perf | Single NIF call | No (Rust) | Low | Team-owned |

## Recommended Approach

**Option A (Pure Elixir) for the initial implementation, with an upgrade path to
Option D (Explorer) if performance becomes a concern.**

For 30-365 point series and hundreds of pairs, pure Elixir provides adequate
throughput within an Oban background worker. The Pearson formula is a well-known
algorithm that any Elixir developer can audit and extend. If profiling reveals
that the correlation job is taking materially longer than the 25-hour cache TTL
(which would only matter if re-runs were needed mid-day), Explorer is the correct
upgrade because it requires adding a single dependency with a precompiled binary
and changing three lines of computation code.

See `docs/architecture/decisions/correlation_engine.md` for the formal decision
record.
