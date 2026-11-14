defmodule MetricFlow.Metrics.ChannelAggregationTest do
  use ExUnit.Case, async: true
  alias MetricFlow.Metrics.ChannelAggregation

  defp sample(id, date, value, weight \\ nil, unit \\ "count"),
    do: %{entity_id: id, date: date, value: value, weight: weight, unit: unit}

  test "snapshots select the latest date separately for each channel" do
    rows = [
      sample(1, ~D[2026-10-01], 100),
      sample(1, ~D[2026-10-03], 120),
      sample(2, ~D[2026-10-02], 50)
    ]

    assert ChannelAggregation.value(rows, :latest) == 170
    assert ChannelAggregation.value(rows, :sum) == 270
  end

  test "weighted ratios preserve denominators across channels and dates" do
    rows = [sample(1, ~D[2026-10-01], 10, 100), sample(2, ~D[2026-10-02], 20, 300)]
    assert ChannelAggregation.value(rows, {:weighted, "views"}) == 17.5

    assert ChannelAggregation.value([sample(1, ~D[2026-10-01], 10, 0)], {:weighted, "views"}) ==
             nil

    assert ChannelAggregation.value([sample(1, ~D[2026-10-01], 10)], {:weighted, "views"}) == nil
  end

  test "unweighted percentages and incompatible currencies remain unavailable" do
    first = sample(1, ~D[2026-10-01], 50)
    second = sample(2, ~D[2026-10-01], 75)
    assert ChannelAggregation.value([first], :per_entity) == 50
    assert ChannelAggregation.value([first, second], :per_entity) == nil
    money = [sample(1, ~D[2026-10-01], 10, nil, "USD"), sample(2, ~D[2026-10-01], 20, nil, "CAD")]
    assert ChannelAggregation.value(money, :sum) == nil
    assert ChannelAggregation.value([], :sum) == nil
  end
end
