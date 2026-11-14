defmodule MetricFlow.DataSync.YouTubeBreakdownSyncTest do
  use MetricFlowTest.DataCase, async: true
  import MetricFlowTest.UsersFixtures

  alias MetricFlow.{Accounts, Metrics}
  alias MetricFlow.DataSync.{YouTubeBreakdownReport, YouTubeBreakdownSync}
  alias MetricFlow.Users.Scope

  @first ~D[2026-10-01]
  @last ~D[2026-10-02]
  @today ~D[2026-10-03]
  @fetched ~U[2026-10-03 12:00:00.000000Z]
  @timezone "America/Los_Angeles"

  setup do
    scope = Scope.for_user(user_fixture())

    {:ok, account} =
      Accounts.create_team_account(scope, %{
        name: "Breakdowns",
        slug: "breakdowns-#{System.unique_integer([:positive])}"
      })

    scope = Scope.put_account_id(scope, account.id)
    {:ok, channel} = Metrics.upsert_channel(scope, "selected", %{display_name: "Channel"})

    %{
      scope: scope,
      channel: channel,
      integration: %{access_token: "access", refresh_token: "refresh"}
    }
  end

  defp fixture(conn, owner, fail_country?) do
    conn = Plug.Conn.fetch_query_params(conn)
    params = conn.query_params
    send(owner, {:request, params})

    if fail_country? and params["dimensions"] == "country" and params["startDate"] == "2026-10-02" do
      Plug.Conn.send_resp(conn, 503, "Unavailable")
    else
      dimensions = String.split(params["dimensions"], ",")
      names = String.split(params["metrics"], ",")
      first = Date.from_iso8601!(params["startDate"])
      last = Date.from_iso8601!(params["endDate"])
      if dimensions == ["country"], do: assert(first == last)

      headers =
        Enum.map(dimensions, &%{"name" => &1, "columnType" => "DIMENSION"}) ++
          Enum.map(names, &%{"name" => &1, "columnType" => "METRIC"})

      rows =
        Enum.map(Date.range(first, last), fn date ->
          Enum.map(dimensions, fn
            "day" -> Date.to_iso8601(date)
            "country" -> "US"
            _ -> "category"
          end) ++ Enum.map(names, fn _ -> 10 end)
        end)

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{"columnHeaders" => headers, "rows" => rows}))
    end
  end

  defp sync(context, plug) do
    YouTubeBreakdownSync.sync(
      context.scope,
      context.integration,
      context.channel,
      @first,
      @today,
      @fetched,
      http_plug: plug
    )
  end

  test "all five breakdowns persist independently and stay out of channel totals", context do
    owner = self()
    outcomes = sync(context, &fixture(&1, owner, false))
    assert length(outcomes) == 5
    assert Enum.all?(outcomes, &match?(%{result: {:ok, _}}, &1))
    assert {:ok, rows} = Metrics.list_entity_observations(context.scope, context.channel.id)
    assert length(rows) == 20

    assert MapSet.new(Enum.map(rows, & &1.breakdown_type)) ==
             MapSet.new(YouTubeBreakdownReport.types())

    for type <- YouTubeBreakdownReport.types() do
      assert {:ok, @last} =
               Metrics.get_entity_cursor(
                 context.scope,
                 context.channel.id,
                 "analytics",
                 @timezone,
                 type
               )
    end

    assert {:ok, nil} =
             Metrics.get_cursor(context.scope, context.channel.id, "analytics", @timezone)

    assert [] == Metrics.channel_time_series(context.scope, date_range: {@first, @last})
  end

  test "a failed country day retains the preceding day and resumes without refetching completed types",
       context do
    owner = self()
    outcomes = sync(context, &fixture(&1, owner, true))
    assert Enum.any?(outcomes, &match?(%{family: "breakdown_country", result: {:error, _}}, &1))

    assert {:ok, @first} =
             Metrics.get_entity_cursor(
               context.scope,
               context.channel.id,
               "analytics",
               @timezone,
               "country"
             )

    assert {:ok, @last} =
             Metrics.get_entity_cursor(
               context.scope,
               context.channel.id,
               "analytics",
               @timezone,
               "device_type"
             )

    assert {:ok, rows} = Metrics.list_entity_observations(context.scope, context.channel.id)
    assert Enum.count(rows, &(&1.breakdown_type == "country")) == 2

    recovery = fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      assert conn.query_params["startDate"] == "2026-10-02"
      assert conn.query_params["dimensions"] in ["day", "country"]
      fixture(conn, owner, false)
    end

    assert Enum.all?(sync(context, recovery), &match?(%{result: {:ok, _}}, &1))

    assert {:ok, @last} =
             Metrics.get_entity_cursor(
               context.scope,
               context.channel.id,
               "analytics",
               @timezone,
               "country"
             )

    assert {:ok, rows} = Metrics.list_entity_observations(context.scope, context.channel.id)
    assert length(rows) == 20
  end
end
