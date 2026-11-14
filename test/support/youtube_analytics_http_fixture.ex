defmodule MetricFlowTest.YouTubeAnalyticsHttpFixture do
  @moduledoc "Synthetic Google HTTP responses for channel analytics acceptance specs."

  def respond(conn, day, metrics) do
    conn = Plug.Conn.fetch_query_params(conn)

    case conn.request_path do
      "/v2/reports" ->
        dimensions = String.split(conn.query_params["dimensions"] || "", ",", trim: true)
        names = String.split(conn.query_params["metrics"] || "", ",", trim: true)

        headers =
          Enum.map(
            dimensions,
            &%{"name" => &1, "columnType" => "DIMENSION", "dataType" => "STRING"}
          ) ++
            Enum.map(names, &%{"name" => &1, "columnType" => "METRIC", "dataType" => "FLOAT"})

        rows =
          if dimensions == ["day"] and
               conn.query_params["startDate"] <= Date.to_iso8601(day) and
               conn.query_params["endDate"] >= Date.to_iso8601(day) do
            [[Date.to_iso8601(day) | Enum.map(names, &Map.fetch!(metrics, &1))]]
          else
            []
          end

        json(conn, %{
          "kind" => "youtubeAnalytics#resultTable",
          "columnHeaders" => headers,
          "rows" => rows
        })

      "/youtube/v3/channels" ->
        json(conn, %{
          "items" => [
            %{
              "id" => "UC_dana_personal",
              "snippet" => %{"title" => "Dana Personal", "publishedAt" => "2020-01-01T00:00:00Z"},
              "contentDetails" => %{"relatedPlaylists" => %{"uploads" => "UU_dana_personal"}},
              "statistics" => %{
                "subscriberCount" => "4500",
                "viewCount" => "210000",
                "videoCount" => "0"
              }
            }
          ]
        })

      path when path in ["/youtube/v3/playlistItems", "/youtube/v3/videos"] ->
        json(conn, %{"items" => []})

      _ ->
        MetricFlowTest.YouTubeOAuthProvider.respond(conn)
    end
  end

  def channel_metrics(overrides \\ %{}) do
    Map.merge(
      %{
        "views" => 1200,
        "engagedViews" => 900,
        "estimatedMinutesWatched" => 3000,
        "averageViewDuration" => 150,
        "averageViewPercentage" => 50,
        "subscribersGained" => 15,
        "subscribersLost" => 2,
        "likes" => 40,
        "dislikes" => 3,
        "comments" => 12,
        "shares" => 8,
        "videosAddedToPlaylists" => 9,
        "videosRemovedFromPlaylists" => 1,
        "estimatedRevenue" => 25,
        "adImpressions" => 5000,
        "cpm" => 5
      },
      overrides
    )
  end

  defp json(conn, body) do
    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.send_resp(200, Jason.encode!(body))
  end
end
