defmodule MetricFlow.DataSync.YouTubeVideosTest do
  use MetricFlowTest.DataCase, async: true
  alias MetricFlow.DataSync.YouTubeVideos

  defp integration, do: %{access_token: "access", refresh_token: "refresh"}

  defp json(conn, body) do
    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.send_resp(200, Jason.encode!(body))
  end

  defp metadata(id, channel) do
    %{
      "id" => id,
      "snippet" => %{
        "channelId" => channel,
        "title" => "Title #{id}",
        "publishedAt" => "2025-01-01T00:00:00Z"
      }
    }
  end

  test "discovers every upload and fetches metadata in batches of at most 50" do
    owner = self()

    plug = fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)

      case conn.request_path do
        "/youtube/v3/playlistItems" ->
          assert conn.query_params["playlistId"] == "uploads"

          {ids, token} =
            case conn.query_params["pageToken"] do
              nil -> {Enum.map(1..50, &Integer.to_string/1), "page-two"}
              "page-two" -> {["51"], nil}
            end

          body = %{"items" => Enum.map(ids, &%{"contentDetails" => %{"videoId" => &1}})}
          body = if token, do: Map.put(body, "nextPageToken", token), else: body
          json(conn, body)

        "/youtube/v3/videos" ->
          ids = String.split(conn.query_params["id"], ",")
          send(owner, {:metadata_batch, length(ids)})
          json(conn, %{"items" => Enum.map(ids, &metadata(&1, "channel"))})
      end
    end

    assert {:ok, videos} =
             YouTubeVideos.fetch(integration(), "channel", "uploads", http_plug: plug)

    assert length(videos) == 51
    assert Enum.map(videos, & &1.external_id) == Enum.map(1..51, &Integer.to_string/1)
    assert Enum.all?(videos, &(&1.created_on == ~D[2025-01-01]))
    assert_received {:metadata_batch, 50}
    assert_received {:metadata_batch, 1}
  end

  test "repeated page tokens stop discovery" do
    owner = self()

    plug = fn conn ->
      send(owner, :request)
      json(conn, %{"items" => [], "nextPageToken" => "repeated"})
    end

    assert {:error, :repeated_page_token} =
             YouTubeVideos.fetch(integration(), "channel", "uploads", http_plug: plug)

    assert_received :request
    assert_received :request
    refute_received :request
  end

  test "metadata from another channel is rejected" do
    plug = fn conn ->
      case conn.request_path do
        "/youtube/v3/playlistItems" ->
          json(conn, %{"items" => [%{"contentDetails" => %{"videoId" => "one"}}]})

        "/youtube/v3/videos" ->
          json(conn, %{"items" => [metadata("one", "other-channel")]})
      end
    end

    assert {:error, :malformed_video_metadata} =
             YouTubeVideos.fetch(integration(), "channel", "uploads", http_plug: plug)
  end

  test "a failed inventory page returns no partial inventory" do
    plug = fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)

      if conn.query_params["pageToken"] do
        Plug.Conn.send_resp(conn, 503, "Unavailable")
      else
        json(conn, %{
          "items" => [%{"contentDetails" => %{"videoId" => "one"}}],
          "nextPageToken" => "next"
        })
      end
    end

    assert {:error, {:provider_http_error, {:http_error, 503}, _}} =
             YouTubeVideos.fetch(integration(), "channel", "uploads", http_plug: plug)
  end
end
