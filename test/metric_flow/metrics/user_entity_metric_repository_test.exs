defmodule MetricFlow.Metrics.UserEntityMetricRepositoryTest do
  use MetricFlowTest.DataCase, async: true

  import MetricFlowTest.UsersFixtures

  alias MetricFlow.Metrics.UserEntityMetricRepository
  alias MetricFlow.Users.Scope

  @day ~D[2026-11-01]
  @other_day ~D[2026-11-02]

  defp scope, do: user_fixture() |> Scope.for_user()

  defp observation(), do: observation(%{})

  defp observation(attrs) do
    Map.merge(
      %{
        provider: :google_business,
        entity_id: "accounts/123/locations/456",
        metric_name: "call_clicks",
        observed_on: @day,
        value: 7.0
      },
      attrs
    )
  end

  test "repeated sync replaces a daily value without adding a duplicate" do
    scope = scope()
    assert {:ok, _} = UserEntityMetricRepository.upsert_observation(scope, observation())

    assert {:ok, updated} =
             UserEntityMetricRepository.upsert_observation(scope, observation(%{value: 11.0}))

    assert updated.value == 11.0
    assert [%{value: 11.0}] = UserEntityMetricRepository.list_observations(scope)
  end

  test "locations, metrics, and days have independent identities" do
    scope = scope()

    attrs = [
      observation(),
      observation(%{entity_id: "accounts/123/locations/789", value: 3.0}),
      observation(%{metric_name: "website_clicks", value: 5.0}),
      observation(%{observed_on: @other_day, value: 9.0})
    ]

    assert {:ok, rows} = UserEntityMetricRepository.upsert_observations(scope, attrs)
    assert length(rows) == 4
    assert length(UserEntityMetricRepository.list_observations(scope)) == 4

    assert [%{value: 7.0}] =
             UserEntityMetricRepository.list_observations(scope,
               entity_id: "accounts/123/locations/456",
               metric_name: "call_clicks",
               date_range: {@day, @day}
             )
  end

  test "a zero daily value is stored and returned" do
    scope = scope()

    assert {:ok, _} =
             UserEntityMetricRepository.upsert_observation(scope, observation(%{value: 0.0}))

    assert [%{value: value}] = UserEntityMetricRepository.list_observations(scope)
    assert value == 0.0
  end

  test "owner comes from scope, not submitted attributes" do
    owner_scope = scope()
    other_scope = scope()

    assert {:ok, row} =
             UserEntityMetricRepository.upsert_observation(
               owner_scope,
               observation(%{user_id: other_scope.user.id})
             )

    assert row.user_id == owner_scope.user.id
    assert UserEntityMetricRepository.list_observations(other_scope) == []
  end

  test "invalid batch rolls back earlier observations" do
    scope = scope()

    assert {:error, %Ecto.Changeset{}} =
             UserEntityMetricRepository.upsert_observations(scope, [
               observation(),
               observation(%{metric_name: nil})
             ])

    assert UserEntityMetricRepository.list_observations(scope) == []
  end

  test "cursor is scoped to the owner and series and can advance" do
    scope = scope()
    other_scope = scope()

    attrs = %{
      provider: :google_business,
      entity_id: "accounts/123/locations/456",
      metric_name: "call_clicks",
      synced_through: @day
    }

    assert nil ==
             UserEntityMetricRepository.get_cursor(
               scope,
               attrs.provider,
               attrs.entity_id,
               attrs.metric_name
             )

    assert {:ok, _} = UserEntityMetricRepository.upsert_cursor(scope, attrs)

    assert {:ok, _} =
             UserEntityMetricRepository.upsert_cursor(scope, %{attrs | synced_through: @other_day})

    assert %{synced_through: @other_day} =
             UserEntityMetricRepository.get_cursor(
               scope,
               attrs.provider,
               attrs.entity_id,
               attrs.metric_name
             )

    assert nil ==
             UserEntityMetricRepository.get_cursor(
               other_scope,
               attrs.provider,
               attrs.entity_id,
               attrs.metric_name
             )
  end
end
