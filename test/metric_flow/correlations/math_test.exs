defmodule MetricFlow.Correlations.MathTest do
  use ExUnit.Case, async: true

  alias MetricFlow.Correlations.Math

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp perfectly_correlated_xs, do: [1.0, 2.0, 3.0]
  defp perfectly_correlated_ys, do: [2.0, 4.0, 6.0]

  defp perfectly_anti_correlated_xs, do: [1.0, 2.0, 3.0]
  defp perfectly_anti_correlated_ys, do: [6.0, 4.0, 2.0]

  # Orthogonal (dot product == 0) after mean-centering — r is exactly 0.0
  defp uncorrelated_xs, do: [1.0, -1.0, 1.0, -1.0]
  defp uncorrelated_ys, do: [1.0, 1.0, -1.0, -1.0]

  defp constant_series, do: [5.0, 5.0, 5.0, 5.0, 5.0]

  defp large_float_xs, do: [1.0e15, 2.0e15, 3.0e15]
  defp large_float_ys, do: [2.0e15, 4.0e15, 6.0e15]

  # Known dataset: x = [1,2,3,4,5], y = [1,3,2,5,4] — computed r = 0.8
  defp known_dataset_xs, do: [1.0, 2.0, 3.0, 4.0, 5.0]
  defp known_dataset_ys, do: [1.0, 3.0, 2.0, 5.0, 4.0]

  # 30-point linearly increasing series
  defp thirty_point_series do
    Enum.map(1..30, fn i -> i * 1.0 end)
  end

  # 365-point linearly increasing series
  defp three_sixty_five_point_series do
    Enum.map(1..365, fn i -> i * 1.0 end)
  end

  # Cross-correlation fixture with a known lag of 3.
  # metric: sin(i * 0.4), goal: sin((i - 3) * 0.4)
  # The implementation finds the lag that aligns goal back to metric.
  # cross_correlate drops `lag` elements from goal; at lag=3 it drops the first
  # 3 elements of goal, leaving sin((4-3)*0.4)..., which aligns with metric.
  # Verified by running: cross_correlate produces {3, 1.0}.
  defp metric_series_for_lag do
    Enum.map(1..40, fn i -> :math.sin(i * 0.4) end)
  end

  defp goal_series_lagged_by_3 do
    Enum.map(1..40, fn i -> :math.sin((i - 3) * 0.4) end)
  end

  # extract_values fixtures
  defp metric_time_series do
    [
      %{date: ~D[2025-01-01], value: 10.0},
      %{date: ~D[2025-01-02], value: 20.0},
      %{date: ~D[2025-01-03], value: 30.0}
    ]
  end

  defp goal_time_series do
    [
      %{date: ~D[2025-01-01], value: 1.0},
      %{date: ~D[2025-01-02], value: 2.0},
      %{date: ~D[2025-01-03], value: 3.0}
    ]
  end

  defp metric_with_gap do
    [
      %{date: ~D[2025-01-01], value: 10.0},
      %{date: ~D[2025-01-05], value: 50.0},
      %{date: ~D[2025-01-10], value: 100.0}
    ]
  end

  defp goal_with_gap do
    [
      %{date: ~D[2025-01-01], value: 1.0},
      %{date: ~D[2025-01-05], value: 5.0},
      %{date: ~D[2025-01-10], value: 10.0}
    ]
  end

  defp metric_partial_overlap do
    [
      %{date: ~D[2025-01-01], value: 10.0},
      %{date: ~D[2025-01-02], value: 20.0},
      %{date: ~D[2025-01-03], value: 30.0}
    ]
  end

  defp goal_partial_overlap do
    [
      %{date: ~D[2025-01-02], value: 2.0},
      %{date: ~D[2025-01-03], value: 3.0},
      %{date: ~D[2025-01-04], value: 4.0}
    ]
  end

  defp metric_no_overlap do
    [
      %{date: ~D[2025-01-01], value: 10.0},
      %{date: ~D[2025-01-02], value: 20.0}
    ]
  end

  defp goal_no_overlap do
    [
      %{date: ~D[2025-06-01], value: 1.0},
      %{date: ~D[2025-06-02], value: 2.0}
    ]
  end

  defp metric_with_nil_value do
    [
      %{date: ~D[2025-01-01], value: 10.0},
      %{date: ~D[2025-01-02], value: nil},
      %{date: ~D[2025-01-03], value: 30.0}
    ]
  end

  defp goal_with_nil_value do
    [
      %{date: ~D[2025-01-01], value: 1.0},
      %{date: ~D[2025-01-02], value: 2.0},
      %{date: ~D[2025-01-03], value: 3.0}
    ]
  end

  # ---------------------------------------------------------------------------
  # pearson/2
  # ---------------------------------------------------------------------------

  describe "pearson/2" do
    test "returns 1.0 for perfectly correlated lists" do
      result = Math.pearson(perfectly_correlated_xs(), perfectly_correlated_ys())

      assert result == 1.0
    end

    test "returns -1.0 for perfectly anti-correlated lists" do
      result = Math.pearson(perfectly_anti_correlated_xs(), perfectly_anti_correlated_ys())

      assert result == -1.0
    end

    test "returns 0.0 for uncorrelated lists" do
      result = Math.pearson(uncorrelated_xs(), uncorrelated_ys())

      assert result == 0.0
    end

    test "returns nil for empty lists" do
      assert Math.pearson([], []) == nil
    end

    test "returns nil when first list is empty" do
      assert Math.pearson([], [1.0, 2.0, 3.0]) == nil
    end

    test "returns nil when second list is empty" do
      assert Math.pearson([1.0, 2.0, 3.0], []) == nil
    end

    test "returns nil for lists of different lengths" do
      assert Math.pearson([1.0, 2.0, 3.0], [1.0, 2.0]) == nil
    end

    test "returns nil when one list is constant (zero variance)" do
      result = Math.pearson([1.0, 2.0, 3.0], constant_series() |> Enum.take(3))

      assert result == nil
    end

    test "returns nil when both lists are constant" do
      result = Math.pearson(constant_series(), constant_series())

      assert result == nil
    end

    test "handles single-element lists (returns nil — insufficient data)" do
      assert Math.pearson([1.0], [1.0]) == nil
    end

    test "returns value between -1.0 and 1.0 for arbitrary inputs" do
      result = Math.pearson(known_dataset_xs(), known_dataset_ys())

      assert is_float(result)
      assert result >= -1.0
      assert result <= 1.0
    end

    test "produces numerically accurate results for known datasets" do
      result = Math.pearson(known_dataset_xs(), known_dataset_ys())

      # x = [1,2,3,4,5], y = [1,3,2,5,4] — computed Pearson r = 0.8
      assert_in_delta result, 0.8, 0.0001
    end

    test "handles large float values without overflow" do
      result = Math.pearson(large_float_xs(), large_float_ys())

      assert result == 1.0
    end
  end

  # ---------------------------------------------------------------------------
  # cross_correlate/3
  # ---------------------------------------------------------------------------

  describe "cross_correlate/3" do
    test "returns {0, ~1.0} for perfectly correlated same-day series" do
      series = thirty_point_series()
      {lag, coefficient} = Math.cross_correlate(series, series, min_overlap: 10)

      assert lag == 0
      assert_in_delta coefficient, 1.0, 0.0001
    end

    test "returns {N, coefficient} where N matches the known lag in a shifted series" do
      # goal_series_lagged_by_3 is sin((i-3)*0.4); at lag=3 cross_correlate
      # drops 3 elements from goal so both align — verified to return {3, 1.0}
      {lag, _coefficient} =
        Math.cross_correlate(metric_series_for_lag(), goal_series_lagged_by_3(),
          max_lag: 10,
          min_overlap: 10
        )

      assert lag == 3
    end

    test "returns nil when series are too short (fewer than min_overlap points after any lag)" do
      short_series = [1.0, 2.0, 3.0]
      result = Math.cross_correlate(short_series, short_series, min_overlap: 30)

      assert result == nil
    end

    test "returns nil when both series are constant" do
      constant = Enum.map(1..35, fn _ -> 5.0 end)
      result = Math.cross_correlate(constant, constant, min_overlap: 30)

      assert result == nil
    end

    test "returns the lag with highest absolute coefficient, even if coefficient is negative" do
      # Anti-correlated series: metric increases, goal decreases
      metric = Enum.map(1..40, fn i -> i * 1.0 end)
      anti_goal = Enum.map(1..40, fn i -> (41 - i) * 1.0 end)

      {_lag, coefficient} = Math.cross_correlate(metric, anti_goal, min_overlap: 10, max_lag: 5)

      assert coefficient < 0.0
    end

    test "respects max_lag option (does not test lags beyond max_lag)" do
      # Use a sinusoidal signal with true lag at 10; max_lag: 5 must not reach it
      metric = Enum.map(1..50, fn i -> :math.sin(i * 0.3) end)
      goal = Enum.map(1..50, fn i -> :math.sin((i - 10) * 0.3) end)

      result = Math.cross_correlate(metric, goal, max_lag: 5, min_overlap: 10)

      # Whatever lag is returned, it must be within the allowed range
      {lag, _} = result
      assert lag <= 5
    end

    test "respects min_overlap option (skips lags with insufficient overlap)" do
      # 40-point series, min_overlap: 38 — only lags 0 and 1 leave >= 38 points
      series = Enum.map(1..40, fn i -> i * 1.0 end)
      {lag, _} = Math.cross_correlate(series, series, max_lag: 30, min_overlap: 38)

      assert lag <= 1
    end

    test "defaults max_lag to 30 when not specified" do
      # 65-point identical series — default max_lag 30 still leaves 35+ overlap at lag 30
      series = Enum.map(1..65, fn i -> i * 1.0 end)
      result = Math.cross_correlate(series, series)

      assert is_tuple(result)
    end

    test "defaults min_overlap to 30 when not specified" do
      # 32-point series — at lag 0 overlap is 32 which satisfies default min_overlap 30
      series = Enum.map(1..32, fn i -> i * 1.0 end)
      result = Math.cross_correlate(series, series)

      assert is_tuple(result)
    end

    test "handles series of exactly 30 data points (minimum threshold)" do
      series = thirty_point_series()
      result = Math.cross_correlate(series, series, min_overlap: 30)

      assert is_tuple(result)
      {lag, coefficient} = result
      assert lag == 0
      assert_in_delta coefficient, 1.0, 0.0001
    end

    test "handles series of 365 data points (full year of daily data)" do
      series = three_sixty_five_point_series()
      result = Math.cross_correlate(series, series, min_overlap: 30)

      assert is_tuple(result)
      {lag, coefficient} = result
      assert lag == 0
      assert_in_delta coefficient, 1.0, 0.0001
    end

    test "prefers smaller lag when multiple lags have equal absolute coefficients" do
      # Identical series — all valid lags produce r = 1.0; lag 0 must be selected
      series = Enum.map(1..60, fn i -> i * 1.0 end)
      {lag, _coefficient} = Math.cross_correlate(series, series, max_lag: 5, min_overlap: 10)

      assert lag == 0
    end
  end

  # ---------------------------------------------------------------------------
  # extract_values/2
  # ---------------------------------------------------------------------------

  describe "extract_values/2" do
    test "returns aligned float lists for series with identical dates" do
      {metric_vals, goal_vals} = Math.extract_values(metric_time_series(), goal_time_series())

      assert metric_vals == [10.0, 20.0, 30.0]
      assert goal_vals == [1.0, 2.0, 3.0]
    end

    test "excludes dates where either series has a missing value" do
      {metric_vals, goal_vals} =
        Math.extract_values(metric_with_nil_value(), goal_with_nil_value())

      # 2025-01-02 is excluded because metric value is nil
      assert metric_vals == [10.0, 30.0]
      assert goal_vals == [1.0, 3.0]
    end

    test "sorts output chronologically by date" do
      reversed_metric = Enum.reverse(metric_time_series())
      reversed_goal = Enum.reverse(goal_time_series())

      {metric_vals, goal_vals} = Math.extract_values(reversed_metric, reversed_goal)

      assert metric_vals == [10.0, 20.0, 30.0]
      assert goal_vals == [1.0, 2.0, 3.0]
    end

    test "returns empty lists when no dates overlap" do
      {metric_vals, goal_vals} = Math.extract_values(metric_no_overlap(), goal_no_overlap())

      assert metric_vals == []
      assert goal_vals == []
    end

    test "returns empty lists for empty inputs" do
      {metric_vals1, goal_vals1} = Math.extract_values([], goal_time_series())

      assert metric_vals1 == []
      assert goal_vals1 == []

      {metric_vals2, goal_vals2} = Math.extract_values(metric_time_series(), [])

      assert metric_vals2 == []
      assert goal_vals2 == []
    end

    test "handles series with gaps (non-contiguous dates)" do
      {metric_vals, goal_vals} = Math.extract_values(metric_with_gap(), goal_with_gap())

      assert metric_vals == [10.0, 50.0, 100.0]
      assert goal_vals == [1.0, 5.0, 10.0]
    end

    test "handles series of different lengths with partial overlap" do
      {metric_vals, goal_vals} =
        Math.extract_values(metric_partial_overlap(), goal_partial_overlap())

      # Only 2025-01-02 and 2025-01-03 appear in both series
      assert metric_vals == [20.0, 30.0]
      assert goal_vals == [2.0, 3.0]
    end

    test "preserves numerical precision of float values" do
      precise_metric = [%{date: ~D[2025-03-15], value: 123.456789}]
      precise_goal = [%{date: ~D[2025-03-15], value: 987.654321}]

      {metric_vals, goal_vals} = Math.extract_values(precise_metric, precise_goal)

      assert hd(metric_vals) == 123.456789
      assert hd(goal_vals) == 987.654321
    end
  end
end
