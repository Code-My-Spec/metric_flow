defmodule MetricFlowTest.YouTubeHistoryHttpFixture do
  @moduledoc "Synthetic dated Google reports bounded by the channel creation date."

  def respond(conn, created_on, last_day) do
    conn = Plug.Conn.fetch_query_params(conn)

    case conn.request_path do
      "/v2/reports" ->
        names = String.split(conn.query_params["metrics"] || "", ",", trim: true)
        dimensions = String.split(conn.query_params["dimensions"] || "", ",", trim: true)
        start_date = Date.from_iso8601!(conn.query_params["startDate"])
        end_date = Date.from_iso8601!(conn.query_params["endDate"])
        values = MetricFlowTest.YouTubeAnalyticsHttpFixture.channel_metrics()

        rows =
          if dimensions == ["day"] do
            Date.range(created_on, last_day)
            |> Enum.filter(
              &(Date.compare(&1, start_date) != :lt and Date.compare(&1, end_date) != :gt)
            )
            |> Enum.map(fn day ->
              metrics = Map.put(values, "views", Date.diff(day, created_on) + 1)
              [Date.to_iso8601(day) | Enum.map(names, &Map.fetch!(metrics, &1))]
            end)
          else
            []
          end

        headers =
          Enum.map(
            dimensions,
            &%{"name" => &1, "columnType" => "DIMENSION", "dataType" => "STRING"}
          ) ++
            Enum.map(names, &%{"name" => &1, "columnType" => "METRIC", "dataType" => "FLOAT"})

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
              "snippet" => %{
                "title" => "Dana Personal",
                "publishedAt" => Date.to_iso8601(created_on) <> "T00:00:00Z"
              },
              "contentDetails" => %{"relatedPlaylists" => %{"uploads" => "UU_dana_personal"}},
              "statistics" => %{
                "subscriberCount" => "4500",
                "viewCount" => "210000",
                "videoCount" => "0"
              }
            }
          ]
        })

      _ ->
        MetricFlowTest.YouTubeAnalyticsHttpFixture.respond(
          conn,
          last_day,
          MetricFlowTest.YouTubeAnalyticsHttpFixture.channel_metrics()
        )
    end
  end

  defp json(conn, body) do
    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.send_resp(200, Jason.encode!(body))
  end
end
