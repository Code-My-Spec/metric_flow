defmodule MetricFlow.Metrics.ChannelProjectionTest do
  use MetricFlowTest.DataCase, async: true

  import MetricFlowTest.UsersFixtures
  alias MetricFlow.Accounts
  alias MetricFlow.Metrics.ChannelProjection
  alias MetricFlow.Metrics.EntityMetricRepository, as: Storage
  alias MetricFlow.Users.Scope

  @day ~D[2026-10-01]
  @fetched ~U[2026-10-03 12:00:00.000000Z]

  defp account_scope(user) do
    scope = Scope.for_user(user)

    {:ok, account} =
      Accounts.create_team_account(scope, %{
        name: "Projection",
        slug: "projection-#{System.unique_integer([:positive])}"
      })

    Scope.put_account_id(scope, account.id)
  end

  test "daily totals and averages remain isolated across accounts" do
    scope = account_scope(user_fixture())
    other = account_scope(scope.user)
    next = Date.add(@day, 1)

    for {owner, values} <- [{scope, [10, 30]}, {other, [1000, 2000]}] do
      {:ok, channel} =
        Storage.upsert_channel(owner, "same-channel", %{display_name: "Shared channel identity"})

      rows =
        Enum.zip([@day, next], values)
        |> Enum.map(fn {date, value} ->
          %{metric_name: "views", report_date: date, value: value}
        end)

      assert {:ok, _} =
               Storage.persist_report(
                 owner,
                 channel.id,
                 "analytics",
                 {@day, next},
                 rows,
                 @fetched
               )
    end

    assert [series] = ChannelProjection.series(scope, date_range: {@day, next})
    assert Enum.map(series.data, & &1.value) == [10.0, 30.0]
    assert %{sum: 40.0, avg: 20.0, count: 2} = ChannelProjection.summary(series)
    stranger = Scope.for_user(user_fixture()) |> Scope.put_account_id(scope.account_id)
    assert [] == ChannelProjection.series(stranger)
    assert [] == ChannelProjection.series(Scope.for_user(scope.user))
  end

  test "snapshot summaries use the latest value for each channel" do
    scope = account_scope(user_fixture())
    next = Date.add(@day, 1)

    for {id, values} <- [{"one", [100, 110]}, {"two", [200, 220]}] do
      {:ok, channel} = Storage.upsert_channel(scope, id, %{display_name: id})

      for {date, value} <- Enum.zip([@day, next], values) do
        assert {:ok, _} =
                 Storage.persist_report(
                   scope,
                   channel.id,
                   "snapshot",
                   {date, date},
                   [%{metric_name: "subscriberCount", report_date: date, value: value}],
                   @fetched
                 )
      end
    end

    assert [series] = ChannelProjection.series(scope)
    assert Enum.map(series.data, & &1.value) == [300.0, 330.0]
    assert %{sum: 330.0} = ChannelProjection.summary(series)
    assert ChannelProjection.aggregate_points(series.data, series.aggregation) == 330.0
  end
end
