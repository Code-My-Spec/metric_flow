defmodule MetricFlow.Metrics.UserEntityMetricObservationTest do
  use MetricFlowTest.DataCase, async: true

  import MetricFlowTest.UsersFixtures

  alias MetricFlow.Metrics.UserEntityMetricObservation
  alias MetricFlow.Repo

  @attrs %{
    provider: :google_business,
    entity_id: "accounts/123/locations/456",
    metric_name: "call_clicks",
    observed_on: ~D[2026-11-07],
    value: 0
  }

  test "requires owner, entity, metric, day, and value" do
    changeset = UserEntityMetricObservation.changeset(%UserEntityMetricObservation{}, %{})

    refute changeset.valid?

    for field <- [:user_id, :entity_id, :metric_name, :observed_on, :value] do
      assert Keyword.has_key?(changeset.errors, field)
    end
  end

  test "preserves a zero value and ignores a supplied owner override" do
    changeset =
      UserEntityMetricObservation.changeset(
        %UserEntityMetricObservation{user_id: 42},
        Map.put(@attrs, :user_id, 99)
      )

    assert changeset.valid?
    assert Ecto.Changeset.get_field(changeset, :user_id) == 42
    assert Ecto.Changeset.get_field(changeset, :value) == 0.0
  end

  test "prevents two observations for the same owner, provider, entity, metric, and day" do
    user = user_fixture()
    observation = %UserEntityMetricObservation{user_id: user.id}

    assert {:ok, _} = observation |> UserEntityMetricObservation.changeset(@attrs) |> Repo.insert()

    assert {:error, changeset} =
             observation
             |> UserEntityMetricObservation.changeset(%{@attrs | value: 11})
             |> Repo.insert()

    assert Keyword.has_key?(changeset.errors, :user_id)
  end
end
