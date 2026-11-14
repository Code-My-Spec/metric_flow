defmodule MetricFlow.Metrics.EntityReportStorageTest do
  use MetricFlowTest.DataCase, async: true
  import MetricFlowTest.UsersFixtures
  alias MetricFlow.{Accounts, Metrics}
  alias MetricFlow.Users.Scope

  @day ~D[2026-10-01]
  @fetched ~U[2026-10-03 12:00:00.000000Z]
  @timezone "America/Los_Angeles"

  setup do
    scope = Scope.for_user(user_fixture())

    {:ok, account} =
      Accounts.create_team_account(scope, %{
        name: "Reports",
        slug: "reports-#{System.unique_integer([:positive])}"
      })

    scope = Scope.put_account_id(scope, account.id)
    {:ok, channel} = Metrics.upsert_channel(scope, "channel", %{display_name: "Channel"})

    videos =
      Enum.map(["one", "two"], fn id ->
        {:ok, video} =
          Metrics.upsert_video(scope, channel.id, id, %{
            display_name: id,
            published_at: ~U[2025-01-01 00:00:00.000000Z]
          })

        video
      end)

    %{scope: scope, channel: channel, videos: videos}
  end

  defp row(value), do: %{metric_name: "views", report_date: @day, value: value}

  defp country(key, value),
    do: Map.merge(row(value), %{breakdown_type: "country", breakdown_key: key})

  test "video totals and breakdowns never enter the channel projection", context do
    %{scope: scope, channel: channel, videos: videos} = context

    assert {:ok, _} =
             Metrics.persist_report(
               scope,
               channel.id,
               "analytics",
               {@day, @day},
               [row(100)],
               @fetched
             )

    for video <- videos do
      for _attempt <- 1..2 do
        assert {:ok, _} =
                 Metrics.persist_entity_report(
                   scope,
                   video.id,
                   "analytics",
                   "total",
                   {@day, @day},
                   [row(30)],
                   @fetched
                 )
      end

      assert {:ok, [stored]} = Metrics.list_entity_observations(scope, video.id)
      assert Decimal.equal?(stored.value, 30)
    end

    assert {:ok, _} =
             Metrics.persist_entity_report(
               scope,
               channel.id,
               "analytics",
               "country",
               {@day, @day},
               [country("US", 80), country("CA", 20)],
               @fetched
             )

    assert [%{data: [%{value: 100.0}]}] =
             Metrics.channel_time_series(scope, date_range: {@day, @day})
  end

  test "successful reconciliation removes obsolete keys without changing totals", %{
    scope: scope,
    channel: channel
  } do
    assert {:ok, _} =
             Metrics.persist_report(
               scope,
               channel.id,
               "analytics",
               {@day, @day},
               [row(100)],
               @fetched
             )

    assert {:ok, _} =
             Metrics.persist_entity_report(
               scope,
               channel.id,
               "analytics",
               "country",
               {@day, @day},
               [country("US", 80), country("CA", 20)],
               @fetched
             )

    assert {:ok, _} =
             Metrics.persist_entity_report(
               scope,
               channel.id,
               "analytics",
               "country",
               {@day, @day},
               [country("US", 90)],
               DateTime.add(@fetched, 60)
             )

    assert {:ok, rows} = Metrics.list_entity_observations(scope, channel.id)

    assert Enum.sort(Enum.map(rows, &{&1.breakdown_type, &1.breakdown_key})) == [
             {"country", "US"},
             {"total", "all"}
           ]

    assert {:ok, @day} =
             Metrics.get_entity_cursor(scope, channel.id, "analytics", @timezone, "country")

    assert {:ok, nil} =
             Metrics.get_entity_cursor(scope, channel.id, "analytics", @timezone, "device_type")
  end

  test "invalid and stale slices retain data and independent cursors", %{
    scope: scope,
    channel: channel
  } do
    assert {:ok, _} =
             Metrics.persist_entity_report(
               scope,
               channel.id,
               "analytics",
               "country",
               {@day, @day},
               [country("US", 80)],
               @fetched
             )

    assert {:error, :duplicate_observation} =
             Metrics.persist_entity_report(
               scope,
               channel.id,
               "analytics",
               "country",
               {@day, @day},
               [country("US", 1), country("US", 2)],
               @fetched
             )

    assert {:error, :invalid_observation} =
             Metrics.persist_entity_report(
               scope,
               channel.id,
               "analytics",
               "country",
               {@day, @day},
               [Map.put(country("CA", 1), :account_id, scope.account_id)],
               @fetched
             )

    assert {:error, :stale_report} =
             Metrics.persist_entity_report(
               scope,
               channel.id,
               "analytics",
               "country",
               {@day, @day},
               [],
               DateTime.add(@fetched, -60)
             )

    assert {:ok, [stored]} = Metrics.list_entity_observations(scope, channel.id)
    assert Decimal.equal?(stored.value, 80)
    assert {:ok, nil} = Metrics.get_cursor(scope, channel.id, "analytics", @timezone)

    assert {:ok, _} =
             Metrics.persist_entity_report(
               scope,
               channel.id,
               "analytics",
               "country",
               {@day, @day},
               [],
               DateTime.add(@fetched, 60)
             )

    assert {:ok, []} = Metrics.list_entity_observations(scope, channel.id)
  end

  test "video revenue advances independently and rejects snapshots", %{
    scope: scope,
    videos: [video | _]
  } do
    revenue = %{metric_name: "estimatedRevenue", report_date: @day, value: 0}

    assert {:ok, _} =
             Metrics.persist_entity_report(
               scope,
               video.id,
               "revenue",
               "total",
               {@day, @day},
               [revenue],
               @fetched
             )

    assert {:ok, @day} = Metrics.get_entity_cursor(scope, video.id, "revenue", @timezone, "total")

    assert {:ok, nil} =
             Metrics.get_entity_cursor(scope, video.id, "analytics", @timezone, "total")

    assert {:error, :invalid_report_grain} =
             Metrics.persist_entity_report(
               scope,
               video.id,
               "snapshot",
               "total",
               {@day, @day},
               [],
               @fetched
             )
  end
end
