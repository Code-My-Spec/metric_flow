# Correlation Engine: Implementation Patterns

Reference implementations and patterns for use inside `MetricFlow.Correlations`.

## Core Math Module

Place computation logic in a dedicated module at
`lib/metric_flow/correlations/math.ex`. This keeps statistical code isolated
from Oban job plumbing and makes it independently testable.

```elixir
defmodule MetricFlow.Correlations.Math do
  @moduledoc """
  Pearson correlation and lag detection for time series pairs.

  All functions operate on lists of `%{date: Date.t(), value: float()}` maps,
  which is the shape returned by `Metrics.query_time_series/3`.
  """

  @doc """
  Extracts the `value` field from a time series list and computes
  the Pearson correlation coefficient.

  Returns `nil` when either series has zero variance or fewer than 2 points.
  """
  @spec pearson([float()], [float()]) :: float() | nil
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

  def pearson(_, _), do: nil

  @doc """
  Computes Pearson r at each candidate lag and returns the lag and coefficient
  with the maximum absolute correlation.

  `lag_range` is an integer Range, e.g. `-30..30`. Positive lag means Y is
  shifted forward in time relative to X (X leads Y). Negative lag means X is
  shifted forward (Y leads X). Lag 0 is the contemporaneous correlation.

  Returns `{optimal_lag :: integer(), coefficient :: float() | nil}`.
  """
  @spec cross_correlate([float()], [float()], Range.t()) ::
          {integer(), float() | nil}
  def cross_correlate(xs, ys, lag_range \\ -30..30) do
    lag_range
    |> Enum.map(fn lag ->
      {sx, sy} = align_for_lag(xs, ys, lag)
      {lag, pearson(sx, sy)}
    end)
    |> Enum.filter(fn {_lag, r} -> not is_nil(r) end)
    |> case do
      [] ->
        {0, nil}

      results ->
        Enum.max_by(results, fn {_lag, r} -> abs(r) end)
    end
  end

  @doc """
  Extracts float values from a `query_time_series/3` result list,
  sorted by date ascending (the default from the repository).
  """
  @spec extract_values([%{date: Date.t(), value: float()}]) :: [float()]
  def extract_values(time_series), do: Enum.map(time_series, & &1.value)

  # --- Private helpers ---

  # Positive lag: X leads Y by `lag` days.
  # Trim the last `lag` elements of X, drop the first `lag` elements of Y.
  defp align_for_lag(xs, ys, lag) when lag > 0 do
    n = length(xs)
    {Enum.take(xs, n - lag), Enum.drop(ys, lag)}
  end

  # Negative lag: Y leads X by `|lag|` days.
  # Drop the first `|lag|` elements of X, trim the last `|lag|` elements of Y.
  defp align_for_lag(xs, ys, lag) when lag < 0 do
    shift = abs(lag)
    n = length(ys)
    {Enum.drop(xs, shift), Enum.take(ys, n - shift)}
  end

  defp align_for_lag(xs, ys, 0), do: {xs, ys}
end
```

## CorrelationWorker Integration

```elixir
defmodule MetricFlow.Correlations.CorrelationWorker do
  use Oban.Worker, queue: :default, max_attempts: 3

  alias MetricFlow.Correlations.Math
  alias MetricFlow.Correlations.CorrelationsRepository
  alias MetricFlow.Metrics
  alias MetricFlow.Users.Scope

  @lag_range -30..30
  @window_days 90

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"account_id" => account_id}}) do
    scope = Scope.for_account(account_id)

    metric_names = Metrics.list_metric_names(scope)
    goal_names = Metrics.list_metric_names(scope, type: :goal)

    end_date = Date.utc_today()
    start_date = Date.add(end_date, -@window_days)
    date_range = {start_date, end_date}

    pairs = for m <- metric_names, g <- goal_names, m != g, do: {m, g}

    results =
      Task.async_stream(
        pairs,
        fn {metric_name, goal_name} ->
          compute_pair(scope, metric_name, goal_name, date_range)
        end,
        timeout: :infinity,
        max_concurrency: System.schedulers_online()
      )
      |> Enum.flat_map(fn {:ok, result} -> List.wrap(result) end)

    CorrelationsRepository.upsert_results(scope, results)
    :ok
  end

  defp compute_pair(scope, metric_name, goal_name, date_range) do
    xs_series = Metrics.query_time_series(scope, metric_name, date_range: date_range)
    ys_series = Metrics.query_time_series(scope, goal_name, date_range: date_range)

    xs = Math.extract_values(xs_series)
    ys = Math.extract_values(ys_series)

    case Math.cross_correlate(xs, ys, @lag_range) do
      {_lag, nil} ->
        nil

      {optimal_lag, coefficient} ->
        %{
          metric_name: metric_name,
          goal_metric_name: goal_name,
          coefficient: coefficient,
          optimal_lag: optimal_lag,
          calculated_at: DateTime.utc_now()
        }
    end
  end
end
```

## Testing the Math Module

The math module is pure functional code and requires no database or Oban setup:

```elixir
defmodule MetricFlow.Correlations.MathTest do
  use ExUnit.Case, async: true

  alias MetricFlow.Correlations.Math

  describe "pearson/2" do
    test "returns 1.0 for perfectly correlated series" do
      xs = [1.0, 2.0, 3.0, 4.0, 5.0]
      ys = [2.0, 4.0, 6.0, 8.0, 10.0]
      assert_in_delta Math.pearson(xs, ys), 1.0, 0.0001
    end

    test "returns -1.0 for perfectly anti-correlated series" do
      xs = [1.0, 2.0, 3.0, 4.0, 5.0]
      ys = [10.0, 8.0, 6.0, 4.0, 2.0]
      assert_in_delta Math.pearson(xs, ys), -1.0, 0.0001
    end

    test "returns nil for zero-variance series" do
      assert Math.pearson([1.0, 1.0, 1.0], [1.0, 2.0, 3.0]) == nil
    end

    test "returns nil when series length < 2" do
      assert Math.pearson([1.0], [1.0]) == nil
    end

    test "returns nil for mismatched lengths" do
      assert Math.pearson([1.0, 2.0], [1.0]) == nil
    end
  end

  describe "cross_correlate/3" do
    test "detects positive lag when x leads y" do
      # x at t=0,1,2,3,4; y follows x by 2 days
      xs = [0.0, 0.0, 1.0, 1.0, 0.0, 0.0, 0.0]
      ys = [0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 0.0]

      {optimal_lag, coefficient} = Math.cross_correlate(xs, ys, -5..5)

      assert optimal_lag == -2 or optimal_lag == 2
      assert coefficient > 0.8
    end

    test "returns {0, nil} when no valid correlations found" do
      # All-zero series yield nil correlations at all lags
      xs = [1.0, 1.0, 1.0]
      ys = [2.0, 2.0, 2.0]
      assert Math.cross_correlate(xs, ys, -1..1) == {0, nil}
    end
  end
end
```

## Upgrading to Explorer

If performance profiling reveals the pure Elixir implementation is a bottleneck,
swap the `Math` module internals to use Explorer without changing the public
interface or the worker. The worker and tests continue to work unchanged.

```elixir
# Add to mix.exs:
# {:explorer, "~> 0.11"}

defmodule MetricFlow.Correlations.Math do
  alias Explorer.Series

  def pearson(xs, ys) when length(xs) == length(ys) and length(xs) > 1 do
    s1 = Series.from_list(xs)
    s2 = Series.from_list(ys)
    Series.correlation(s1, s2, method: :pearson)
  end

  def pearson(_, _), do: nil

  def cross_correlate(xs, ys, lag_range \\ -30..30) do
    n = length(xs)
    s_xs = Series.from_list(xs)
    s_ys = Series.from_list(ys)

    lag_range
    |> Enum.map(fn lag ->
      {sx, sy} = align_for_lag(s_xs, s_ys, n, lag)
      {lag, Series.correlation(sx, sy, method: :pearson)}
    end)
    |> Enum.filter(fn {_lag, r} -> not is_nil(r) end)
    |> case do
      [] -> {0, nil}
      results -> Enum.max_by(results, fn {_lag, r} -> abs(r) end)
    end
  end

  def extract_values(time_series), do: Enum.map(time_series, & &1.value)

  defp align_for_lag(xs, ys, n, lag) when lag > 0 do
    {Series.head(xs, n - lag), Series.tail(ys, n - lag)}
  end

  defp align_for_lag(xs, ys, n, lag) when lag < 0 do
    shift = abs(lag)
    {Series.tail(xs, n - shift), Series.head(ys, n - shift)}
  end

  defp align_for_lag(xs, ys, _n, 0), do: {xs, ys}
end
```

Note that `Series.from_list/1` is called once per pair (not once per lag),
building the series objects outside the lag loop. `Series.head/2` and
`Series.tail/2` are O(1) slice operations in Polars and do not copy the
underlying buffer.

## Numerical Accuracy Notes

The Pearson formula is numerically sensitive to large or near-identical values.
The single-pass algorithm used in the pure Elixir implementation (computing
deviations from the mean) is the standard formulation and avoids the catastrophic
cancellation that can occur with the two-pass sum-of-squares formula:

    r = (n*sum(xy) - sum(x)*sum(y)) / sqrt((n*sum(x^2) - sum(x)^2) * (n*sum(y^2) - sum(y)^2))

Always compute deviations from the mean before summing products. Explorer/Polars
uses a numerically stable algorithm internally.

For marketing analytics use cases (values in the range of dollars, clicks, and
sessions), float64 precision is more than sufficient and no special handling is
required beyond guarding for zero-variance series.
