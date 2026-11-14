defmodule MetricFlow.DataSync.YouTubeBreakdownsTest do
  use MetricFlowTest.DataCase, async: true
  alias MetricFlow.DataSync.YouTubeBreakdowns

  @day ~D[2026-10-01]

  defp integration, do: %{access_token: "access", refresh_token: "refresh"}

  defp respond(conn, keys) do
    body = %{
      "columnHeaders" => [
        %{"name" => "day", "columnType" => "DIMENSION"},
        %{"name" => "insightTrafficSourceType", "columnType" => "DIMENSION"},
        %{"name" => "views", "columnType" => "METRIC"},
        %{"name" => "estimatedMinutesWatched", "columnType" => "METRIC"}
      ],
      "rows" => Enum.map(keys, &["2026-10-01", &1, 1, 2])
    }

    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.send_resp(200, Jason.encode!(body))
  end

  test "collects every page using one-based row indexes" do
    owner = self()

    plug = fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      assert conn.query_params["dimensions"] == "day,insightTrafficSourceType"
      assert conn.query_params["ids"] == "channel==selected"
      send(owner, {:page, conn.query_params["startIndex"]})

      case conn.query_params["startIndex"] do
        "1" -> respond(conn, Enum.map(1..200, &Integer.to_string/1))
        "201" -> respond(conn, ["last"])
      end
    end

    assert {:ok, rows} =
             YouTubeBreakdowns.fetch(integration(), "selected", "traffic_source", {@day, @day},
               http_plug: plug
             )

    assert length(rows) == 402
    assert_received {:page, "1"}
    assert_received {:page, "201"}
    refute_received {:page, _}
  end

  test "a repeated page is rejected instead of looping or duplicating observations" do
    plug = fn conn -> respond(conn, Enum.map(1..200, &Integer.to_string/1)) end

    assert {:error, :duplicate_report_page} =
             YouTubeBreakdowns.fetch(integration(), "selected", "traffic_source", {@day, @day},
               http_plug: plug
             )
  end

  test "a failed later page returns no partial slice" do
    plug = fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)

      case conn.query_params["startIndex"] do
        "1" -> respond(conn, Enum.map(1..200, &Integer.to_string/1))
        "201" -> Plug.Conn.send_resp(conn, 503, "Unavailable")
      end
    end

    assert {:error, {:provider_http_error, {:http_error, 503}, _}} =
             YouTubeBreakdowns.fetch(integration(), "selected", "traffic_source", {@day, @day},
               http_plug: plug
             )
  end
end
