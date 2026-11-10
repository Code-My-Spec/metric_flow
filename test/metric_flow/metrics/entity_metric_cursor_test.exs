defmodule MetricFlow.Metrics.EntityMetricCursorTest do
  use ExUnit.Case, async: true

  alias MetricFlow.Metrics.EntityMetricCursor

  test "requires an owner, entity, metric, and completed day" do
    changeset = EntityMetricCursor.changeset(%EntityMetricCursor{}, %{})

    refute changeset.valid?
    assert Keyword.has_key?(changeset.errors, :user_id)
    assert Keyword.has_key?(changeset.errors, :entity_id)
    assert Keyword.has_key?(changeset.errors, :metric_name)
    assert Keyword.has_key?(changeset.errors, :synced_through)
  end

  test "accepts a checkpoint with an owner set by the caller" do
    cursor = %EntityMetricCursor{user_id: 42}

    changeset =
      EntityMetricCursor.changeset(cursor, %{
        provider: :google_business,
        entity_id: "accounts/123/locations/456",
        metric_name: "call_clicks",
        synced_through: ~D[2026-11-07],
        user_id: 99
      })

    assert changeset.valid?
    assert Ecto.Changeset.get_field(changeset, :user_id) == 42
    assert Ecto.Changeset.get_field(changeset, :synced_through) == ~D[2026-11-07]
  end
end
