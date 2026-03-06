defmodule MetricFlow.Correlations.Math do
  @moduledoc """
  Pure functional module implementing statistical calculations for correlation
  analysis.

  Provides Pearson correlation coefficient computation and time-lagged
  cross-correlation (TLCC) for detecting optimal lag between metric pairs.
  Zero external dependencies — upgrade path to Explorer documented in ADR.
  """

  @doc """
  Computes the Pearson correlation coefficient between two equal-length lists
  of floats.

  Uses a single-pass deviation-from-mean approach. Returns nil for empty lists,
  mismatched lengths, single-element lists, or constant (zero-variance) series.
  Result is clamped to [-1.0, 1.0] to handle floating-point rounding.
  """
  @spec pearson([float()], [float()]) :: float() | nil
  def pearson([], _), do: nil
  def pearson(_, []), do: nil
  def pearson([_], [_]), do: nil

  def pearson(xs, ys) when length(xs) != length(ys), do: nil

  def pearson(xs, ys) do
    n = length(xs)
    mean_x = Enum.sum(xs) / n
    mean_y = Enum.sum(ys) / n

    {sum_xy, sum_xx, sum_yy} =
      Enum.zip_reduce(xs, ys, {0.0, 0.0, 0.0}, fn x, y, {sxy, sxx, syy} ->
        dx = x - mean_x
        dy = y - mean_y
        {sxy + dx * dy, sxx + dx * dx, syy + dy * dy}
      end)

    case {sum_xx, sum_yy} do
      {+0.0, _} -> nil
      {_, +0.0} -> nil
      _ -> (sum_xy / :math.sqrt(sum_xx * sum_yy)) |> clamp(-1.0, 1.0)
    end
  end

  @doc """
  Computes time-lagged cross-correlation between two series, testing lags from
  0 to max_lag days. Returns `{optimal_lag, coefficient}` where optimal_lag is
  the lag with the highest absolute Pearson coefficient.

  Options:
  - `:max_lag` — maximum lag to test (default: 30)
  - `:min_overlap` — minimum data points after lag shift (default: 30)
  """
  @spec cross_correlate([float()], [float()], keyword()) :: {integer(), float()} | nil
  def cross_correlate(metric_values, goal_values, opts \\ []) do
    max_lag = Keyword.get(opts, :max_lag, 30)
    min_overlap = Keyword.get(opts, :min_overlap, 30)

    0..max_lag
    |> Enum.reduce([], fn lag, acc ->
      shifted_goal = Enum.drop(goal_values, lag)
      trimmed_metric = Enum.take(metric_values, length(shifted_goal))
      maybe_correlate(trimmed_metric, shifted_goal, lag, min_overlap, acc)
    end)
    |> select_optimal()
  end

  @doc """
  Converts two lists of metric time-series maps into aligned float lists.

  Each map is expected to have `:date` and `:value` keys. Only dates present
  in both series are included. Output is sorted chronologically.
  """
  @spec extract_values([map()], [map()]) :: {[float()], [float()]}
  def extract_values([], _), do: {[], []}
  def extract_values(_, []), do: {[], []}

  def extract_values(metric_series, goal_series) do
    metric_map = Map.new(metric_series, &{&1.date, &1.value})
    goal_map = Map.new(goal_series, &{&1.date, &1.value})

    common_dates =
      MapSet.intersection(
        MapSet.new(Map.keys(metric_map)),
        MapSet.new(Map.keys(goal_map))
      )
      |> Enum.sort(Date)

    Enum.reduce(common_dates, {[], []}, fn date, {ms, gs} ->
      m = Map.get(metric_map, date)
      g = Map.get(goal_map, date)

      if is_number(m) and is_number(g) do
        {[m | ms], [g | gs]}
      else
        {ms, gs}
      end
    end)
    |> then(fn {ms, gs} -> {Enum.reverse(ms), Enum.reverse(gs)} end)
  end

  # Select the pair with the highest absolute coefficient.
  # Prefer smaller lag when absolute values are equal.
  defp select_optimal([]), do: nil

  defp select_optimal(pairs) do
    Enum.min_by(pairs, fn {lag, r} -> {-abs(r), lag} end)
  end

  defp maybe_correlate(trimmed_metric, _shifted_goal, _lag, min_overlap, acc)
       when length(trimmed_metric) < min_overlap,
       do: acc

  defp maybe_correlate(trimmed_metric, shifted_goal, lag, _min_overlap, acc) do
    case pearson(trimmed_metric, shifted_goal) do
      nil -> acc
      r -> [{lag, r} | acc]
    end
  end

  defp clamp(value, min, max) do
    value |> Kernel.max(min) |> Kernel.min(max)
  end
end
