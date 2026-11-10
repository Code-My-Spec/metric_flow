defmodule MetricFlow.Metrics.UserChannelProjectionTest do
  use MetricFlowTest.DataCase, async: true

  import MetricFlowTest.UsersFixtures

  alias MetricFlow.Metrics.UserChannelProjection
  alias MetricFlow.Metrics.Metric
  alias MetricFlow.Repo
  alias MetricFlow.Users.Scope

  test "projects daily totals without combining users, providers, or locations" do
    user = user_fixture()
    other_user = user_fixture()
    scope = Scope.for_user(user)
    day = ~D[2026-11-07]

    insert_metric!(user, :google_business, "location-a", day, "call_clicks", 2.0)
    insert_metric!(user, :google_business, "location-a", day, "call_clicks", 3.0)
    insert_metric!(user, :google_business, "location-b", day, "call_clicks", 7.0)
    insert_metric!(user, :google_ads, nil, day, "clicks", 11.0)
    insert_metric!(other_user, :google_business, "location-a", day, "call_clicks", 99.0)

    assert UserChannelProjection.list_daily(scope, provider: :google_business) == [
             %{
               provider: :google_business,
               location_id: "location-a",
               date: day,
               metric_name: "call_clicks",
               value: 5.0
             },
             %{
               provider: :google_business,
               location_id: "location-b",
               date: day,
               metric_name: "call_clicks",
               value: 7.0
             }
           ]
  end

  test "includes both date boundaries and preserves stored zero values" do
    user = user_fixture()
    scope = Scope.for_user(user)

    insert_metric!(user, :google_business, "location-a", ~D[2026-11-06], "call_clicks", 9.0)
    insert_metric!(user, :google_business, "location-a", ~D[2026-11-07], "call_clicks", 0.0)
    insert_metric!(user, :google_business, "location-a", ~D[2026-11-08], "call_clicks", 4.0)
    insert_metric!(user, :google_business, "location-a", ~D[2026-11-09], "call_clicks", 8.0)

    rows = UserChannelProjection.list_daily(scope, date_range: {~D[2026-11-07], ~D[2026-11-08]})

    assert Enum.map(rows, &{&1.date, &1.value}) == [
             {~D[2026-11-07], 0.0},
             {~D[2026-11-08], 4.0}
           ]
  end

  defp insert_metric!(user, provider, location_id, date, name, value) do
    %Metric{
      user_id: user.id,
      provider: provider,
      metric_type: "engagement",
      metric_name: name,
      value: value,
      recorded_at: DateTime.new!(date, ~T[12:00:00.000000], "Etc/UTC"),
      dimensions: if(location_id, do: %{"location_id" => location_id}, else: %{})
    }
    |> Repo.insert!()
  end
end
