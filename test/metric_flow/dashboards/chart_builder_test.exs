defmodule MetricFlow.Dashboards.ChartBuilderTest do
  use ExUnit.Case, async: true

  alias MetricFlow.Dashboards.ChartBuilder

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp time_series_data do
    [
      %{date: ~D[2025-01-01], value: 100.0},
      %{date: ~D[2025-01-02], value: 150.5},
      %{date: ~D[2025-01-03], value: 200.0}
    ]
  end

  defp single_time_series_point do
    [%{date: ~D[2025-06-15], value: 42.0}]
  end

  defp bar_chart_data do
    [
      %{category: "Google Ads", value: 5000.0},
      %{category: "Facebook Ads", value: 3200.75},
      %{category: "QuickBooks", value: 12_000.0}
    ]
  end

  defp single_bar_chart_point do
    [%{category: "Google Ads", value: 9999.0}]
  end

  defp summary_stats do
    %{sum: 450.5, avg: 150.17, min: 100.0, max: 200.0, count: 3}
  end

  defp zero_summary_stats do
    %{sum: 0.0, avg: 0.0, min: 0.0, max: 0.0, count: 0}
  end

  # ---------------------------------------------------------------------------
  # build_time_series_spec/2
  # ---------------------------------------------------------------------------

  describe "build_time_series_spec/2" do
    test "returns a map with a '$schema' key pointing to a Vega-Lite schema URL" do
      spec = ChartBuilder.build_time_series_spec("Impressions", time_series_data())

      assert is_map(spec)
      assert Map.has_key?(spec, "$schema")
      assert spec["$schema"] =~ "vega-lite"
    end

    test "returned map includes a 'mark' key configured for a line chart" do
      spec = ChartBuilder.build_time_series_spec("Impressions", time_series_data())

      assert is_map(spec["mark"])
      assert spec["mark"]["type"] == "line"
      assert spec["mark"]["point"] == true
    end

    test "returned map includes an 'encoding' key with 'x' mapped to the 'date' field with temporal type" do
      spec = ChartBuilder.build_time_series_spec("Impressions", time_series_data())

      assert is_map(spec["encoding"])
      assert spec["encoding"]["x"]["field"] == "date"
      assert spec["encoding"]["x"]["type"] == "temporal"
    end

    test "returned map includes an 'encoding' key with 'y' mapped to the 'value' field with quantitative type" do
      spec = ChartBuilder.build_time_series_spec("Impressions", time_series_data())

      assert is_map(spec["encoding"])
      assert spec["encoding"]["y"]["field"] == "value"
      assert spec["encoding"]["y"]["type"] == "quantitative"
    end

    test "title in the returned spec matches the metric_name argument" do
      spec = ChartBuilder.build_time_series_spec("Monthly Revenue", time_series_data())

      assert spec["title"] == "Monthly Revenue"
    end

    test "data values in the spec contain the provided data points with dates serialized as ISO 8601 strings" do
      spec = ChartBuilder.build_time_series_spec("Clicks", time_series_data())

      values = spec["data"]["values"]
      assert is_list(values)
      assert length(values) == 3

      assert Enum.any?(values, fn v -> v["date"] == "2025-01-01" && v["value"] == 100.0 end)
      assert Enum.any?(values, fn v -> v["date"] == "2025-01-02" && v["value"] == 150.5 end)
      assert Enum.any?(values, fn v -> v["date"] == "2025-01-03" && v["value"] == 200.0 end)
    end

    test "returns a valid Vega-Lite spec when given an empty data list" do
      spec = ChartBuilder.build_time_series_spec("Empty Metric", [])

      assert is_map(spec)
      assert Map.has_key?(spec, "$schema")
      assert spec["data"]["values"] == []
    end

    test "returns a valid Vega-Lite spec when given a single data point" do
      spec = ChartBuilder.build_time_series_spec("Single Point", single_time_series_point())

      assert is_map(spec)
      assert Map.has_key?(spec, "$schema")

      values = spec["data"]["values"]
      assert length(values) == 1
      assert hd(values)["date"] == "2025-06-15"
      assert hd(values)["value"] == 42.0
    end
  end

  # ---------------------------------------------------------------------------
  # build_bar_chart_spec/2
  # ---------------------------------------------------------------------------

  describe "build_bar_chart_spec/2" do
    test "returns a map with a '$schema' key pointing to a Vega-Lite schema URL" do
      spec = ChartBuilder.build_bar_chart_spec("Spend by Platform", bar_chart_data())

      assert is_map(spec)
      assert Map.has_key?(spec, "$schema")
      assert spec["$schema"] =~ "vega-lite"
    end

    test "returned map includes a 'mark' key configured for a bar chart" do
      spec = ChartBuilder.build_bar_chart_spec("Spend by Platform", bar_chart_data())

      assert spec["mark"] == "bar"
    end

    test "returned map includes an 'encoding' key with 'x' mapped to the 'category' field with nominal type" do
      spec = ChartBuilder.build_bar_chart_spec("Spend by Platform", bar_chart_data())

      assert is_map(spec["encoding"])
      assert spec["encoding"]["x"]["field"] == "category"
      assert spec["encoding"]["x"]["type"] == "nominal"
    end

    test "returned map includes an 'encoding' key with 'y' mapped to the 'value' field with quantitative type" do
      spec = ChartBuilder.build_bar_chart_spec("Spend by Platform", bar_chart_data())

      assert is_map(spec["encoding"])
      assert spec["encoding"]["y"]["field"] == "value"
      assert spec["encoding"]["y"]["type"] == "quantitative"
    end

    test "title in the returned spec matches the title argument" do
      spec = ChartBuilder.build_bar_chart_spec("Revenue by Channel", bar_chart_data())

      assert spec["title"] == "Revenue by Channel"
    end

    test "returns a valid Vega-Lite spec when given an empty data list" do
      spec = ChartBuilder.build_bar_chart_spec("Empty Chart", [])

      assert is_map(spec)
      assert Map.has_key?(spec, "$schema")
      assert spec["data"]["values"] == []
    end

    test "returns a valid Vega-Lite spec when given a single category data point" do
      spec = ChartBuilder.build_bar_chart_spec("Single Category", single_bar_chart_point())

      assert is_map(spec)
      assert Map.has_key?(spec, "$schema")

      values = spec["data"]["values"]
      assert length(values) == 1
      assert hd(values)["category"] == "Google Ads"
      assert hd(values)["value"] == 9999.0
    end
  end

  # ---------------------------------------------------------------------------
  # build_summary_card_spec/2
  # ---------------------------------------------------------------------------

  describe "build_summary_card_spec/2" do
    test "returns a map with a metric_name key matching the metric_name argument" do
      result = ChartBuilder.build_summary_card_spec("Total Revenue", summary_stats())

      assert is_map(result)
      assert result.metric_name == "Total Revenue"
    end

    test "returned map includes the sum value from stats" do
      result = ChartBuilder.build_summary_card_spec("Clicks", summary_stats())

      assert result.sum == 450.5
    end

    test "returned map includes the avg value from stats" do
      result = ChartBuilder.build_summary_card_spec("Clicks", summary_stats())

      assert result.avg == 150.17
    end

    test "returned map includes the min value from stats" do
      result = ChartBuilder.build_summary_card_spec("Clicks", summary_stats())

      assert result.min == 100.0
    end

    test "returned map includes the max value from stats" do
      result = ChartBuilder.build_summary_card_spec("Clicks", summary_stats())

      assert result.max == 200.0
    end

    test "returned map includes the count value from stats" do
      result = ChartBuilder.build_summary_card_spec("Clicks", summary_stats())

      assert result.count == 3
    end

    test "handles stats where all numeric values are zero" do
      result = ChartBuilder.build_summary_card_spec("Zero Metric", zero_summary_stats())

      assert result.metric_name == "Zero Metric"
      assert result.sum == 0.0
      assert result.avg == 0.0
      assert result.min == 0.0
      assert result.max == 0.0
    end

    test "handles stats where count is 0" do
      result = ChartBuilder.build_summary_card_spec("No Data", zero_summary_stats())

      assert result.count == 0
    end
  end
end
