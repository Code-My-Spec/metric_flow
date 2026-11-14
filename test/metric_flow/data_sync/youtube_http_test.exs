defmodule MetricFlow.DataSync.YouTubeHttpTest do
  use MetricFlowTest.DataCase, async: true

  alias MetricFlow.DataSync.YouTubeHttp

  @data_url "https://www.googleapis.com/youtube/v3/channels"
  @analytics_url "https://youtubeanalytics.googleapis.com/v2/reports"

  defp integration, do: %{access_token: "access", refresh_token: "refresh"}

  test "quota is retried once, then further calls to that API stop" do
    owner = self()

    plug = fn conn ->
      send(owner, {:request, conn.host})

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(
        403,
        Jason.encode!(%{
          "error" => %{
            "errors" => [%{"reason" => "quotaExceeded"}]
          }
        })
      )
    end

    assert {:error, {:provider_http_error, :quota_exceeded, _}} =
             YouTubeHttp.get(integration(), @data_url, [], http_plug: plug)

    assert_received {:request, "www.googleapis.com"}
    assert_received {:request, "www.googleapis.com"}

    assert {:error, :quota_exceeded} =
             YouTubeHttp.get(integration(), @data_url, [], http_plug: plug)

    refute_received {:request, _}

    assert %{rows: [[2, true]]} =
             Repo.query!(
               "SELECT requests, blocked FROM youtube_request_budgets WHERE api = $1",
               ["data"]
             )

    success = fn conn ->
      send(owner, :analytics_request)

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, "{}")
    end

    assert {:ok, %{}} = YouTubeHttp.get(integration(), @analytics_url, [], http_plug: success)
    assert_received :analytics_request
  end

  test "ordinary report failure does not block the other report family" do
    assert {:error, {:provider_http_error, {:http_error, 503}, _}} =
             YouTubeHttp.get(integration(), @analytics_url, [],
               http_plug: fn conn -> Plug.Conn.send_resp(conn, 503, "Unavailable") end
             )

    assert {:ok, %{}} =
             YouTubeHttp.get(integration(), @analytics_url, [],
               http_plug: fn conn ->
                 conn
                 |> Plug.Conn.put_resp_content_type("application/json")
                 |> Plug.Conn.send_resp(200, "{}")
               end
             )

    assert %{rows: [[2, false]]} =
             Repo.query!(
               "SELECT requests, blocked FROM youtube_request_budgets WHERE api = $1",
               ["analytics"]
             )
  end
end
