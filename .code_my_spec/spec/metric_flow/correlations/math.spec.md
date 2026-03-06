# MetricFlow.Correlations.Math

Pure functional module implementing statistical calculations. Provides pearson/2 (Pearson correlation coefficient from two float lists), cross_correlate/3 (time-lagged cross-correlation testing lags 0-30, returning optimal lag and coefficient), and extract_values/1 (converts metric time series to aligned float lists). Zero external dependencies — upgrade path to Explorer documented in ADR.

## Type

module

## Functions

### pearson/2

Computes the Pearson correlation coefficient between two equal-length lists of floats. Uses a single-pass deviation-from-mean approach that avoids catastrophic cancellation.

```elixir
@spec pearson([float()], [float()]) :: float() | nil
```

**Process**:
1. Return nil if either list is empty or lists have different lengths
2. Calculate mean of each list
3. Use Enum.zip_reduce/4 to compute in a single pass: sum of (xi - mean_x)(yi - mean_y), sum of (xi - mean_x)^2, sum of (yi - mean_y)^2
4. Return nil if either standard deviation is zero (constant series)
5. Calculate r = covariance / (std_x * std_y)
6. Clamp result to [-1.0, 1.0] to handle floating-point rounding

**Test Assertions**:
- returns 1.0 for perfectly correlated lists (e.g., [1, 2, 3] and [2, 4, 6])
- returns -1.0 for perfectly anti-correlated lists (e.g., [1, 2, 3] and [6, 4, 2])
- returns 0.0 for uncorrelated lists
- returns nil for empty lists
- returns nil for lists of different lengths
- returns nil when one list is constant (zero variance)
- returns nil when both lists are constant
- handles single-element lists (returns nil — insufficient data)
- returns value between -1.0 and 1.0 for arbitrary inputs
- produces numerically accurate results for known datasets
- handles large float values without overflow

### cross_correlate/3

Computes the time-lagged cross-correlation between two series, testing lags from 0 to max_lag days. Returns the lag with the highest absolute Pearson coefficient and the coefficient at that lag.

```elixir
@spec cross_correlate([float()], [float()], keyword()) :: {integer(), float()} | nil
```

**Process**:
1. Extract max_lag from opts (default: 30)
2. Extract min_overlap from opts (default: 30, minimum data points after lag shift)
3. For each lag from 0 to max_lag:
   a. Shift the series: drop first `lag` elements from goal series, take corresponding elements from metric series
   b. Skip if overlap is less than min_overlap
   c. Compute pearson/2 on the overlapping segments
4. Collect all non-nil {lag, coefficient} pairs
5. Return nil if no valid pairs found
6. Select the pair with the highest absolute coefficient value
7. Return {optimal_lag, coefficient}

**Test Assertions**:
- returns {0, ~1.0} for perfectly correlated same-day series
- returns {N, coefficient} where N matches the known lag in a shifted series
- returns nil when series are too short (fewer than min_overlap points after any lag)
- returns nil when both series are constant
- returns the lag with highest absolute coefficient, even if coefficient is negative
- respects max_lag option (does not test lags beyond max_lag)
- respects min_overlap option (skips lags with insufficient overlap)
- defaults max_lag to 30 when not specified
- defaults min_overlap to 30 when not specified
- handles series of exactly 30 data points (minimum threshold)
- handles series of 365 data points (full year of daily data)
- prefers smaller lag when multiple lags have equal absolute coefficients

### extract_values/2

Converts a list of metric time-series maps into two aligned float lists suitable for pearson/2 or cross_correlate/3. Aligns by date and fills missing dates with nil (excluded from correlation).

```elixir
@spec extract_values([map()], [map()]) :: {[float()], [float()]}
```

**Process**:
1. Build a date-indexed map from each series (date => value)
2. Compute the union of all dates from both series
3. Sort dates chronologically
4. For each date, extract the value from both series
5. Keep only date pairs where both series have non-nil values
6. Return two aligned float lists

**Test Assertions**:
- returns aligned float lists for series with identical dates
- excludes dates where either series has a missing value
- sorts output chronologically by date
- returns empty lists when no dates overlap
- returns empty lists for empty inputs
- handles series with gaps (non-contiguous dates)
- handles series of different lengths with partial overlap
- preserves numerical precision of float values

## Dependencies

- None
