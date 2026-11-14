defmodule MetricFlow.DataSync.YouTubeReportsTest do
  use MetricFlowTest.DataCase, async: true
  alias MetricFlow.DataSync.YouTubeReports

  @first ~D[2025-01-01]

  defp integration, do: %{access_token: "access", refresh_token: "refresh"}

  defp respond(conn, dates) do
    body = %{
      "columnHeaders" => [
        %{"name" => "day", "columnType" => "DIMENSION"},
        %{"name" => "views", "columnType" => "METRIC"}
      ],
      "rows" => Enum.map(dates, &[Date.to_iso8601(&1), 1])
    }

    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.send_resp(200, Jason.encode!(body))
  end

  test "fetches all 548 days with bounded requests" do
    last = Date.add(@first, 547)

    plug = fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      first = Date.from_iso8601!(conn.query_params["startDate"])
      finish = Date.from_iso8601!(conn.query_params["endDate"])
      assert Date.diff(finish, first) < 180
      assert conn.query_params["ids"] == "channel==selected"
      assert conn.query_params["dimensions"] == "day"
      respond(conn, Date.range(first, finish))
    end

    assert {:ok, result} =
             YouTubeReports.fetch(integration(), "selected", ["views"], {@first, last},
               http_plug: plug
             )

    assert result.through_date == last
    assert length(result.observations) == 548
    assert result.observations |> Enum.map(& &1.report_date) |> Enum.uniq() |> length() == 548
  end

  test "video reports retain the channel identity and filter exactly one video" do
    plug = fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      assert conn.query_params["ids"] == "channel==selected"
      assert conn.query_params["filters"] == "video==video-one"
      assert conn.query_params["dimensions"] == "day"
      respond(conn, [@first])
    end

    assert {:ok, %{observations: [_]}} =
             YouTubeReports.fetch_video(
               integration(),
               "selected",
               "video-one",
               ["views"],
               {@first, @first},
               http_plug: plug
             )

    assert {:error, :invalid_video_id} =
             YouTubeReports.fetch_video(
               integration(),
               "selected",
               "one;country==US",
               ["views"],
               {@first, @first},
               http_plug: plug
             )
  end

  test "reports the available date instead of the requested end date" do
    last = Date.add(@first, 5)
    available = Date.add(@first, 2)
    plug = fn conn -> respond(conn, Date.range(@first, available)) end

    assert {:ok, result} =
             YouTubeReports.fetch(integration(), "selected", ["views"], {@first, last},
               http_plug: plug
             )

    assert result.through_date == available

    assert {:ok, %{observations: [], through_date: nil}} =
             YouTubeReports.fetch(integration(), "selected", ["views"], {@first, last},
               http_plug: fn conn -> respond(conn, []) end
             )
  end

  test "a later request failure does not return an incomplete report for persistence" do
    plug = fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      first = Date.from_iso8601!(conn.query_params["startDate"])
      finish = Date.from_iso8601!(conn.query_params["endDate"])

      if first == @first,
        do: respond(conn, Date.range(first, finish)),
        else: Plug.Conn.send_resp(conn, 503, "Unavailable")
    end

    assert {:error, {:provider_http_error, {:http_error, 503}, _}} =
             YouTubeReports.fetch(
               integration(),
               "selected",
               ["views"],
               {@first, Date.add(@first, 200)},
               http_plug: plug
             )
  end
end
