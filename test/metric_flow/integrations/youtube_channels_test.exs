defmodule MetricFlow.Integrations.YouTubeChannelsTest do
  use ExUnit.Case, async: true
  alias MetricFlow.Integrations.YouTubeChannels

  defp json(conn, status, body) do
    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.send_resp(status, Jason.encode!(body))
  end

  test "retrieves all pages and deduplicates channels" do
    plug = fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      assert conn.query_params["mine"] == "true"
      assert conn.query_params["part"] == "snippet"
      assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-token"]
      first = %{"id" => "one", "snippet" => %{"title" => "Personal"}}
      second = %{"id" => "two", "snippet" => %{"title" => "Brand"}}

      case conn.query_params["pageToken"] do
        nil -> json(conn, 200, %{"items" => [first], "nextPageToken" => "page-two"})
        "page-two" -> json(conn, 200, %{"items" => [first, second]})
      end
    end

    assert {:ok, [%{id: "one", name: "Personal"}, %{id: "two", name: "Brand"}]} =
             YouTubeChannels.list_channels("test-token", http_plug: plug)
  end

  test "empty results remain distinct from failed or malformed responses" do
    assert {:ok, []} =
             YouTubeChannels.list_channels("token",
               http_plug: fn conn -> json(conn, 200, %{"items" => []}) end
             )

    for {status, expected} <- [{401, :unauthorized}, {403, :forbidden}, {500, {:http_error, 500}}] do
      assert {:error, ^expected} =
               YouTubeChannels.list_channels("token",
                 http_plug: fn conn ->
                   json(conn, status, %{"error" => %{"message" => "denied"}})
                 end
               )
    end

    for body <- [
          %{},
          %{"items" => [nil]},
          %{"items" => [%{"id" => "one"}]},
          %{"items" => [], "nextPageToken" => 42}
        ] do
      assert {:error, :malformed_response} =
               YouTubeChannels.list_channels("token",
                 http_plug: fn conn -> json(conn, 200, body) end
               )
    end
  end

  test "repeated pagination tokens terminate with an error" do
    assert {:error, :invalid_pagination} =
             YouTubeChannels.list_channels("token",
               http_plug: fn conn ->
                 json(conn, 200, %{"items" => [], "nextPageToken" => "repeated"})
               end
             )
  end
end
