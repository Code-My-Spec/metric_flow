defmodule MetricFlow.Metrics.EntityReportSliceTest do
  use ExUnit.Case, async: true

  alias MetricFlow.Metrics.EntityMetricObservation
  alias MetricFlow.Metrics.EntityReportSlice

  @day ~D[2026-11-07]

  test "keeps location values separate and preserves a stored zero" do
    observations = [
      observation("locations/2", "call_clicks", 7.0),
      observation("locations/1", "call_clicks", 0.0),
      observation("locations/1", "website_clicks", 12.0),
      observation("locations/1", "review_count", 3.0, :google_business_reviews)
    ]

    slice = EntityReportSlice.build(observations, :google_business)

    assert slice.metric_names == ["call_clicks", "website_clicks"]

    assert Enum.map(slice.daily_rows, &{&1.entity_id, &1.date, &1.metric_name, &1.value}) == [
             {"locations/1", @day, "call_clicks", 0.0},
             {"locations/1", @day, "website_clicks", 12.0},
             {"locations/2", @day, "call_clicks", 7.0}
           ]

    assert Enum.map(EntityReportSlice.for_entity(slice, "locations/1"), & &1.value) == [
             0.0,
             12.0
           ]
  end

  test "returns an empty report when the provider has no observations" do
    assert EntityReportSlice.build([], :google_business) == %{
             provider: :google_business,
             metric_names: [],
             daily_rows: []
           }
  end

  defp observation(entity_id, metric_name, value),
    do: observation(entity_id, metric_name, value, :google_business)

  defp observation(entity_id, metric_name, value, provider) do
    %EntityMetricObservation{
      provider: provider,
      entity_id: entity_id,
      observed_on: @day,
      metric_name: metric_name,
      value: value
    }
  end
end
