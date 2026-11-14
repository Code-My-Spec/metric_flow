defmodule MetricFlow.Metrics.UserChannelReportSliceTest do
  use ExUnit.Case, async: true

  alias MetricFlow.Metrics.UserChannelReportSlice

  test "keeps daily locations separate and preserves a stored zero" do
    day = ~D[2026-11-07]

    rows = [
      row(:google_business, "locations/2", day, "call_clicks", 7.0),
      row(:google_business, "locations/1", day, "call_clicks", 0.0),
      row(:google_business, "locations/1", day, "website_clicks", 12.0),
      row(:google_business_reviews, "locations/1", day, "review_count", 3.0)
    ]

    slice = UserChannelReportSlice.build(rows, :google_business)

    assert slice.metric_names == ["call_clicks", "website_clicks"]

    assert Enum.map(slice.daily_rows, &{&1.location_id, &1.metric_name, &1.value}) == [
             {"locations/1", "call_clicks", 0.0},
             {"locations/1", "website_clicks", 12.0},
             {"locations/2", "call_clicks", 7.0}
           ]

    assert Enum.map(UserChannelReportSlice.for_location(slice, "locations/1"), & &1.value) == [
             0.0,
             12.0
           ]
  end

  test "returns an empty report when the provider has no observations" do
    assert UserChannelReportSlice.build([], :google_business) == %{
             provider: :google_business,
             metric_names: [],
             daily_rows: []
           }
  end

  defp row(provider, location_id, date, metric_name, value) do
    %{
      provider: provider,
      location_id: location_id,
      date: date,
      metric_name: metric_name,
      value: value
    }
  end
end
