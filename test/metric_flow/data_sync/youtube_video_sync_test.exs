defmodule MetricFlow.DataSync.YouTubeVideoSyncTest do
  use MetricFlowTest.DataCase, async: true
  import MetricFlowTest.UsersFixtures
  alias MetricFlow.{Accounts, Metrics}
  alias MetricFlow.DataSync.YouTubeVideoSync
  alias MetricFlow.Users.Scope

  @today ~D[2026-10-03]
  @day ~D[2026-10-02]
  @fetched ~U[2026-10-03 12:00:00.000000Z]
  @timezone "America/Los_Angeles"

  setup do
    scope = Scope.for_user(user_fixture())

    {:ok, account} =
      Accounts.create_team_account(scope, %{
        name: "Video sync",
        slug: "video-sync-#{System.unique_integer([:positive])}"
      })

    scope = Scope.put_account_id(scope, account.id)
    {:ok, channel} = Metrics.upsert_channel(scope, "selected", %{display_name: "Channel"})

    integration = %{
      access_token: "access",
      refresh_token: "refresh",
      granted_scopes: ["https://www.googleapis.com/auth/yt-analytics-monetary.readonly"]
    }

    %{scope: scope, channel: channel, integration: integration}
  end

  defp json(conn, body) do
    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.send_resp(200, Jason.encode!(body))
  end

  defp fixture(conn, fail_family, owner) do
    conn = Plug.Conn.fetch_query_params(conn)

    case conn.request_path do
      "/youtube/v3/playlistItems" ->
        json(conn, %{"items" => [%{"contentDetails" => %{"videoId" => "video-one"}}]})

      "/youtube/v3/videos" ->
        json(conn, %{
          "items" => [
            %{
              "id" => "video-one",
              "snippet" => %{
                "channelId" => "selected",
                "title" => "Video",
                "publishedAt" => "2026-10-01T00:00:00Z"
              }
            }
          ]
        })

      "/v2/reports" ->
        names = String.split(conn.query_params["metrics"], ",")
        family = if "estimatedRevenue" in names, do: "revenue", else: "analytics"
        send(owner, {:report, family, conn.query_params})

        if family == fail_family do
          Plug.Conn.send_resp(conn, 503, "Unavailable")
        else
          headers =
            [%{"name" => "day", "columnType" => "DIMENSION"}] ++
              Enum.map(names, &%{"name" => &1, "columnType" => "METRIC"})

          date = conn.query_params["endDate"]

          json(conn, %{
            "columnHeaders" => headers,
            "rows" => [[date | Enum.map(names, fn _ -> 2 end)]]
          })
        end
    end
  end

  for failed_family <- ["analytics", "revenue"] do
    @failed_family failed_family
    test "#{failed_family} failure leaves the other family persisted", context do
      owner = self()
      failed = @failed_family

      outcomes =
        YouTubeVideoSync.sync(
          context.scope,
          context.integration,
          context.channel,
          "uploads",
          @today,
          @fetched, http_plug: &fixture(&1, failed, owner))

      assert Enum.any?(outcomes, &match?(%{result: {:error, _}}, &1))
      assert {:ok, [video]} = Metrics.list_videos(context.scope, context.channel.id)
      succeeded = if failed == "analytics", do: "revenue", else: "analytics"

      assert {:ok, @day} =
               Metrics.get_entity_cursor(context.scope, video.id, succeeded, @timezone, "total")

      assert {:ok, rows} = Metrics.list_entity_observations(context.scope, video.id)
      assert Enum.any?(rows, &(&1.source_report == succeeded))

      assert {:ok, nil} =
               Metrics.get_entity_cursor(context.scope, video.id, failed, @timezone, "total")

      assert [] == Metrics.channel_time_series(context.scope, date_range: {@day, @day})
    end
  end

  test "next sync requests only dates after each successful video cursor", context do
    owner = self()
    opts = [http_plug: &fixture(&1, nil, owner)]

    YouTubeVideoSync.sync(
      context.scope,
      context.integration,
      context.channel,
      "uploads",
      @today,
      @fetched,
      opts
    )

    for family <- ["analytics", "revenue"] do
      assert_received {:report, ^family, params}
      assert params["startDate"] == "2026-10-01"
      assert params["filters"] == "video==video-one"
    end

    YouTubeVideoSync.sync(
      context.scope,
      context.integration,
      context.channel,
      "uploads",
      Date.add(@today, 1),
      DateTime.add(@fetched, 86400),
      opts
    )

    for family <- ["analytics", "revenue"] do
      assert_received {:report, ^family, params}
      assert params["startDate"] == "2026-10-03"
      assert params["endDate"] == "2026-10-03"
    end
  end
end
