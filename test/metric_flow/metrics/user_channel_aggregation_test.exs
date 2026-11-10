defmodule MetricFlow.Metrics.UserChannelAggregationTest do
  use ExUnit.Case, async: true

  alias MetricFlow.Metrics.UserChannelAggregation
  alias MetricFlow.Metrics.Metric

  test "aggregates each day, metric, and location separately" do
    date = ~D[2026-11-07]
    recorded_at = DateTime.new!(date, ~T[00:00:00], "Etc/UTC")

    metrics = [
      metric("locations/1", "call_clicks", 3.0, recorded_at),
      metric("locations/1", "call_clicks", 4.0, recorded_at),
      metric("locations/2", "call_clicks", 5.0, recorded_at),
      metric("locations/1", "website_clicks", 6.0, recorded_at),
      metric("locations/1", "call_clicks", 2.0, DateTime.add(recorded_at, 86_400))
    ]

    assert UserChannelAggregation.aggregate_daily(metrics) == %{
             {:google_business, "locations/1", date, "call_clicks"} => 7.0,
             {:google_business, "locations/2", date, "call_clicks"} => 5.0,
             {:google_business, "locations/1", date, "website_clicks"} => 6.0,
             {:google_business, "locations/1", Date.add(date, 1), "call_clicks"} => 2.0
           }
  end

  test "treats a missing value as zero and accepts persisted string dimension keys" do
    recorded_at = ~U[2026-11-07 00:00:00Z]

    metric = %Metric{
      provider: :google_business,
      metric_name: "call_clicks",
      value: nil,
      recorded_at: recorded_at,
      dimensions: %{"location_id" => "locations/1"}
    }

    assert UserChannelAggregation.aggregate_daily([metric]) == %{
             {:google_business, "locations/1", ~D[2026-11-07], "call_clicks"} => 0.0
           }
  end

  defp metric(location_id, name, value, recorded_at) do
    %Metric{
      provider: :google_business,
      metric_name: name,
      value: value,
      recorded_at: recorded_at,
      dimensions: %{location_id: location_id}
    }
  end
end
