defmodule MetricFlow.Metrics.EntityMetricRepositoryTest do
  use MetricFlowTest.DataCase, async: true

  import MetricFlowTest.UsersFixtures
  alias MetricFlow.Accounts
  alias MetricFlow.Metrics.EntityMetricRepository, as: Storage
  alias MetricFlow.Users.Scope

  @date ~D[2026-10-01]
  @fetched ~U[2026-10-03 12:00:00.000000Z]
  @timezone "America/Los_Angeles"

  defp account_scope(user) do
    scope = Scope.for_user(user)

    {:ok, account} =
      Accounts.create_team_account(scope, %{
        name: "Channel metrics",
        slug: "channel-metrics-#{System.unique_integer([:positive])}"
      })

    Scope.put_account_id(scope, account.id)
  end

  defp row(name, value, date \\ @date),
    do: %{metric_name: name, value: value, report_date: date}

  setup do
    scope = account_scope(user_fixture())
    {:ok, channel} = Storage.upsert_channel(scope, "channel-one", %{display_name: "Original"})
    %{scope: scope, channel: channel}
  end

  test "channel identity survives renamed metadata and stays account scoped", %{
    scope: scope,
    channel: channel
  } do
    assert {:ok, renamed} =
             Storage.upsert_channel(scope, "channel-one", %{display_name: "Renamed"})

    assert renamed.id == channel.id
    assert renamed.display_name == "Renamed"
    other_scope = account_scope(scope.user)

    assert {:ok, other} =
             Storage.upsert_channel(other_scope, "channel-one", %{display_name: "Other"})

    refute other.id == channel.id
    assert {:error, :not_found} = Storage.get_channel(other_scope, channel.id)

    assert {:error, :not_found} =
             Storage.persist_report(
               other_scope,
               channel.id,
               "analytics",
               {@date, @date},
               [row("views", 5)],
               @fetched
             )

    stranger = Scope.for_user(user_fixture()) |> Scope.put_account_id(scope.account_id)
    assert {:error, :unauthorized} = Storage.list_channels(stranger)

    assert {:error, :unauthorized} =
             Storage.upsert_channel(stranger, "channel-one", %{display_name: "Stolen"})
  end

  test "read-only members can read but cannot replace observations", %{
    scope: scope,
    channel: channel
  } do
    reader = user_fixture()
    assert {:ok, _} = Accounts.add_user_to_account(scope, reader.id, scope.account_id, :read_only)
    reader_scope = Scope.for_user(reader) |> Scope.put_account_id(scope.account_id)
    assert {:ok, _} = Storage.get_channel(reader_scope, channel.id)

    assert {:error, :unauthorized} =
             Storage.persist_report(
               reader_scope,
               channel.id,
               "analytics",
               {@date, @date},
               [row("views", 5)],
               @fetched
             )
  end

  test "retries replace a complete slice without duplicating or erasing other dates", %{
    scope: scope,
    channel: channel
  } do
    next = Date.add(@date, 1)
    rows = [row("views", 10), row("likes", 2), row("views", 20, next)]

    assert {:ok, _} =
             Storage.persist_report(scope, channel.id, "analytics", {@date, next}, rows, @fetched)

    assert {:ok, _} =
             Storage.persist_report(scope, channel.id, "analytics", {@date, next}, rows, @fetched)

    assert {:ok, original} = Storage.list_observations(scope, channel.id)
    assert length(original) == 3

    assert {:ok, _} =
             Storage.persist_report(
               scope,
               channel.id,
               "analytics",
               {@date, @date},
               [row("views", 12)],
               DateTime.add(@fetched, 60)
             )

    assert {:ok, updated} = Storage.list_observations(scope, channel.id)

    assert Enum.map(updated, &{&1.metric_name, &1.report_date, Decimal.to_integer(&1.value)}) == [
             {"views", @date, 12},
             {"views", next, 20}
           ]

    assert {:ok, ^next} = Storage.get_cursor(scope, channel.id, "analytics", @timezone)
    assert {:ok, nil} = Storage.get_cursor(scope, channel.id, "revenue", @timezone)
  end

  test "invalid, stale and noncontiguous reports retain observations and progress", %{
    scope: scope,
    channel: channel
  } do
    assert {:ok, _} =
             Storage.persist_report(
               scope,
               channel.id,
               "analytics",
               {@date, @date},
               [row("views", 10)],
               @fetched
             )

    assert {:error, :invalid_observation} =
             Storage.persist_report(
               scope,
               channel.id,
               "analytics",
               {@date, @date},
               [Map.put(row("views", 99), :unit, "USD")],
               @fetched
             )

    assert {:error, :stale_report} =
             Storage.persist_report(
               scope,
               channel.id,
               "analytics",
               {@date, @date},
               [row("views", 1)],
               DateTime.add(@fetched, -60)
             )

    gap = Date.add(@date, 2)

    assert {:error, :noncontiguous_report} =
             Storage.persist_report(
               scope,
               channel.id,
               "analytics",
               {gap, gap},
               [row("views", 99, gap)],
               @fetched
             )

    assert {:ok, [observation]} = Storage.list_observations(scope, channel.id)
    assert Decimal.equal?(observation.value, 10)
    assert {:ok, @date} = Storage.get_cursor(scope, channel.id, "analytics", @timezone)
  end

  test "revenue remains independent and distinguishes zero from an empty report", %{
    scope: scope,
    channel: channel
  } do
    assert {:ok, _} =
             Storage.persist_report(
               scope,
               channel.id,
               "revenue",
               {@date, @date},
               [row("estimatedRevenue", 0)],
               @fetched
             )

    assert {:ok, [observation]} = Storage.list_observations(scope, channel.id)
    assert Decimal.equal?(observation.value, 0)
    assert {:ok, nil} = Storage.get_cursor(scope, channel.id, "analytics", @timezone)

    assert {:ok, _} =
             Storage.persist_report(
               scope,
               channel.id,
               "revenue",
               {@date, @date},
               [],
               DateTime.add(@fetched, 60)
             )

    assert {:ok, []} = Storage.list_observations(scope, channel.id)
    assert {:ok, @date} = Storage.get_cursor(scope, channel.id, "revenue", @timezone)
  end
end
