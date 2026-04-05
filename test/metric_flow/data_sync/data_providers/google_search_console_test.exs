defmodule MetricFlow.DataSync.DataProviders.GoogleSearchConsoleTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias MetricFlow.DataSync.DataProviders.GoogleSearchConsole
  alias MetricFlow.Integrations.Integration

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp future_expires_at do
    DateTime.add(DateTime.utc_now(), 3600, :second)
  end

  defp past_expires_at do
    DateTime.add(DateTime.utc_now(), -3600, :second)
  end

  defp valid_integration do
    struct!(Integration,
      id: 1,
      provider: :google_search_console,
      access_token: "ya29.valid_gsc_token",
      refresh_token: "1//refresh_token",
      expires_at: future_expires_at(),
      granted_scopes: ["https://www.googleapis.com/auth/webmasters.readonly"],
      provider_metadata: %{"site_url" => "https://example.com/"},
      user_id: 1
    )
  end

  defp valid_integration_without_site_url do
    struct!(Integration,
      id: 2,
      provider: :google_search_console,
      access_token: "ya29.valid_gsc_token",
      refresh_token: "1//refresh_token",
      expires_at: future_expires_at(),
      granted_scopes: ["https://www.googleapis.com/auth/webmasters.readonly"],
      provider_metadata: %{},
      user_id: 1
    )
  end

  defp expired_integration do
    struct!(Integration,
      id: 3,
      provider: :google_search_console,
      access_token: "ya29.expired_token",
      refresh_token: "1//expired_refresh_token",
      expires_at: past_expires_at(),
      granted_scopes: ["https://www.googleapis.com/auth/webmasters.readonly"],
      provider_metadata: %{"site_url" => "https://example.com/"},
      user_id: 1
    )
  end

  defp single_row_api_response do
    Jason.encode!(%{
      "rows" => [
        %{
          "keys" => ["2026-01-15"],
          "clicks" => 120,
          "impressions" => 4500,
          "ctr" => 0.02666666,
          "position" => 8.345678
        }
      ]
    })
  end

  defp two_row_api_response do
    Jason.encode!(%{
      "rows" => [
        %{
          "keys" => ["2026-01-15"],
          "clicks" => 120,
          "impressions" => 4500,
          "ctr" => 0.02666666,
          "position" => 8.345678
        },
        %{
          "keys" => ["2026-01-16"],
          "clicks" => 200,
          "impressions" => 6000,
          "ctr" => 0.03333333,
          "position" => 6.1234
        }
      ]
    })
  end

  defp empty_rows_response do
    Jason.encode!(%{"rows" => []})
  end

  defp no_rows_key_response do
    Jason.encode!(%{"responseAggregationType" => "byPage"})
  end

  # Generates a response with exactly 25_000 rows (triggers pagination)
  defp full_page_response do
    rows =
      Enum.map(1..25_000, fn i ->
        date = Date.add(~D[2025-01-01], i - 1) |> Date.to_iso8601()
        %{"keys" => [date], "clicks" => i, "impressions" => i * 10, "ctr" => 0.1, "position" => 5.0}
      end)

    Jason.encode!(%{"rows" => rows})
  end

  defp build_stub_plug(status, body) do
    fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(status, body)
    end
  end

  defp capture_request_plug(test_pid) do
    fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      send(test_pid, {:request, conn, body})

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, single_row_api_response())
    end
  end

  defp get_req_header(%Plug.Conn{} = conn, header_name) do
    Enum.flat_map(conn.req_headers, fn {name, value} ->
      if String.downcase(name) == header_name, do: [value], else: []
    end)
  end

  # ---------------------------------------------------------------------------
  # fetch_metrics/2
  # ---------------------------------------------------------------------------

  describe "fetch_metrics/2" do
    test "returns ok tuple with list of metrics for valid integration and site_url option" do
      plug = build_stub_plug(200, single_row_api_response())

      assert {:ok, metrics} =
               GoogleSearchConsole.fetch_metrics(valid_integration_without_site_url(),
                 site_url: "https://example.com/",
                 http_plug: plug
               )

      assert is_list(metrics)
      assert metrics != []
    end

    test "resolves site_url from opts when provided" do
      test_pid = self()

      plug = fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        send(test_pid, {:request, conn, body})

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, single_row_api_response())
      end

      capture_log(fn ->
        GoogleSearchConsole.fetch_metrics(valid_integration_without_site_url(),
          site_url: "https://opts-example.com/",
          http_plug: plug
        )
      end)

      assert_receive {:request, conn, _body}
      assert String.contains?(conn.request_path, URI.encode_www_form("https://opts-example.com/"))
    end

    test "resolves site_url from integration.provider_metadata when not in opts" do
      test_pid = self()

      plug = fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        send(test_pid, {:request, conn, body})

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, single_row_api_response())
      end

      capture_log(fn ->
        GoogleSearchConsole.fetch_metrics(valid_integration(), http_plug: plug)
      end)

      assert_receive {:request, conn, _body}
      assert String.contains?(conn.request_path, URI.encode_www_form("https://example.com/"))
    end

    test "returns error :missing_site_url when site_url is absent from both opts and metadata" do
      assert {:error, :missing_site_url} =
               GoogleSearchConsole.fetch_metrics(valid_integration_without_site_url(), [])
    end

    test "returns error :missing_site_url when site_url is an empty string" do
      integration =
        struct!(Integration,
          id: 5,
          provider: :google_search_console,
          access_token: "ya29.valid_gsc_token",
          refresh_token: "1//refresh_token",
          expires_at: future_expires_at(),
          granted_scopes: ["https://www.googleapis.com/auth/webmasters.readonly"],
          provider_metadata: %{"site_url" => ""},
          user_id: 1
        )

      assert {:error, :missing_site_url} =
               GoogleSearchConsole.fetch_metrics(integration, [])
    end

    test "returns error :unauthorized when integration token is expired" do
      assert {:error, :unauthorized} =
               GoogleSearchConsole.fetch_metrics(expired_integration(), [])
    end

    test "includes Bearer token in Authorization header" do
      test_pid = self()
      plug = capture_request_plug(test_pid)

      capture_log(fn ->
        GoogleSearchConsole.fetch_metrics(valid_integration(), http_plug: plug)
      end)

      assert_receive {:request, conn, _body}
      assert ["Bearer ya29.valid_gsc_token"] = get_req_header(conn, "authorization")
    end

    test "builds correct searchAnalytics/query URL with URL-encoded site_url" do
      test_pid = self()
      plug = capture_request_plug(test_pid)

      capture_log(fn ->
        GoogleSearchConsole.fetch_metrics(valid_integration(), http_plug: plug)
      end)

      assert_receive {:request, conn, _body}
      encoded_site = URI.encode_www_form("https://example.com/")
      assert String.contains?(conn.request_path, encoded_site)
      assert String.contains?(conn.request_path, "searchAnalytics/query")
    end

    test "posts JSON body with startDate, endDate, dimensions [\"date\"], rowLimit, startRow" do
      test_pid = self()
      plug = capture_request_plug(test_pid)

      capture_log(fn ->
        GoogleSearchConsole.fetch_metrics(valid_integration(), http_plug: plug)
      end)

      assert_receive {:request, _conn, body}
      {:ok, decoded} = Jason.decode(body)

      assert Map.has_key?(decoded, "startDate")
      assert Map.has_key?(decoded, "endDate")
      assert decoded["dimensions"] == ["date"]
      assert Map.has_key?(decoded, "rowLimit")
      assert Map.has_key?(decoded, "startRow")
    end

    test "defaults date range to last 548 days when date_range not provided" do
      test_pid = self()
      plug = capture_request_plug(test_pid)

      capture_log(fn ->
        GoogleSearchConsole.fetch_metrics(valid_integration(), http_plug: plug)
      end)

      assert_receive {:request, _conn, body}
      {:ok, decoded} = Jason.decode(body)

      today = Date.utc_today()
      expected_start = Date.add(today, -548)
      expected_end = Date.add(today, -1)

      assert decoded["startDate"] == Date.to_iso8601(expected_start)
      assert decoded["endDate"] == Date.to_iso8601(expected_end)
    end

    test "uses date_range from opts when provided" do
      test_pid = self()
      plug = capture_request_plug(test_pid)
      start_date = ~D[2026-01-01]
      end_date = ~D[2026-01-31]

      capture_log(fn ->
        GoogleSearchConsole.fetch_metrics(valid_integration(),
          date_range: {start_date, end_date},
          http_plug: plug
        )
      end)

      assert_receive {:request, _conn, body}
      {:ok, decoded} = Jason.decode(body)

      assert decoded["startDate"] == "2026-01-01"
      assert decoded["endDate"] == "2026-01-31"
    end

    test "formats dates as YYYY-MM-DD in request body" do
      test_pid = self()
      plug = capture_request_plug(test_pid)
      start_date = ~D[2025-03-05]
      end_date = ~D[2025-03-31]

      capture_log(fn ->
        GoogleSearchConsole.fetch_metrics(valid_integration(),
          date_range: {start_date, end_date},
          http_plug: plug
        )
      end)

      assert_receive {:request, _conn, body}
      {:ok, decoded} = Jason.decode(body)

      assert decoded["startDate"] =~ ~r/^\d{4}-\d{2}-\d{2}$/
      assert decoded["endDate"] =~ ~r/^\d{4}-\d{2}-\d{2}$/
    end

    test "transforms API rows to list of metric maps" do
      plug = build_stub_plug(200, two_row_api_response())

      assert {:ok, metrics} =
               GoogleSearchConsole.fetch_metrics(valid_integration(), http_plug: plug)

      assert is_list(metrics)
      assert Enum.all?(metrics, &is_map/1)

      for metric <- metrics do
        assert Map.has_key?(metric, :metric_type)
        assert Map.has_key?(metric, :metric_name)
        assert Map.has_key?(metric, :value)
        assert Map.has_key?(metric, :recorded_at)
        assert Map.has_key?(metric, :dimensions)
        assert Map.has_key?(metric, :provider)
      end
    end

    test "emits one metric map per metric name per row (clicks, impressions, ctr, position)" do
      plug = build_stub_plug(200, single_row_api_response())

      assert {:ok, metrics} =
               GoogleSearchConsole.fetch_metrics(valid_integration(), http_plug: plug)

      # Single row with 4 metrics = 4 metric maps
      assert length(metrics) == 4

      metric_names = Enum.map(metrics, & &1.metric_name)
      assert "clicks" in metric_names
      assert "impressions" in metric_names
      assert "ctr" in metric_names
      assert "position" in metric_names
    end

    test "sets metric_type to \"search\" for all metrics" do
      plug = build_stub_plug(200, two_row_api_response())

      assert {:ok, metrics} =
               GoogleSearchConsole.fetch_metrics(valid_integration(), http_plug: plug)

      for metric <- metrics do
        assert metric.metric_type == "search"
      end
    end

    test "sets provider to :google_search_console for all metrics" do
      plug = build_stub_plug(200, two_row_api_response())

      assert {:ok, metrics} =
               GoogleSearchConsole.fetch_metrics(valid_integration(), http_plug: plug)

      for metric <- metrics do
        assert metric.provider == :google_search_console
      end
    end

    test "sets recorded_at to midnight UTC DateTime from row date key" do
      plug = build_stub_plug(200, single_row_api_response())

      assert {:ok, metrics} =
               GoogleSearchConsole.fetch_metrics(valid_integration(), http_plug: plug)

      for metric <- metrics do
        assert %DateTime{} = metric.recorded_at
        assert metric.recorded_at.hour == 0
        assert metric.recorded_at.minute == 0
        assert metric.recorded_at.second == 0
        assert metric.recorded_at.time_zone == "Etc/UTC"
      end
    end

    test "sets dimensions map with date key on each metric" do
      plug = build_stub_plug(200, single_row_api_response())

      assert {:ok, metrics} =
               GoogleSearchConsole.fetch_metrics(valid_integration(), http_plug: plug)

      for metric <- metrics do
        assert is_map(metric.dimensions)
        assert Map.has_key?(metric.dimensions, :date)
        assert metric.dimensions.date == "2026-01-15"
      end
    end

    test "rounds ctr to 4 decimal places" do
      plug = build_stub_plug(200, single_row_api_response())

      assert {:ok, metrics} =
               GoogleSearchConsole.fetch_metrics(valid_integration(), http_plug: plug)

      ctr_metric = Enum.find(metrics, fn m -> m.metric_name == "ctr" end)
      assert ctr_metric != nil
      # 0.02666666 rounded to 4 decimal places = 0.0267
      assert ctr_metric.value == 0.0267
    end

    test "rounds position to 2 decimal places" do
      plug = build_stub_plug(200, single_row_api_response())

      assert {:ok, metrics} =
               GoogleSearchConsole.fetch_metrics(valid_integration(), http_plug: plug)

      position_metric = Enum.find(metrics, fn m -> m.metric_name == "position" end)
      assert position_metric != nil
      # 8.345678 rounded to 2 decimal places = 8.35
      assert position_metric.value == 8.35
    end

    test "returns integer values for clicks and impressions" do
      plug = build_stub_plug(200, single_row_api_response())

      assert {:ok, metrics} =
               GoogleSearchConsole.fetch_metrics(valid_integration(), http_plug: plug)

      clicks_metric = Enum.find(metrics, fn m -> m.metric_name == "clicks" end)
      impressions_metric = Enum.find(metrics, fn m -> m.metric_name == "impressions" end)

      assert clicks_metric != nil
      assert impressions_metric != nil
      assert is_integer(clicks_metric.value)
      assert is_integer(impressions_metric.value)
    end

    test "handles empty rows list with empty accumulated result" do
      plug = build_stub_plug(200, empty_rows_response())

      assert {:ok, []} =
               GoogleSearchConsole.fetch_metrics(valid_integration(), http_plug: plug)
    end

    test "handles 200 response with no rows key as empty result" do
      plug = build_stub_plug(200, no_rows_key_response())

      assert {:ok, []} =
               GoogleSearchConsole.fetch_metrics(valid_integration(), http_plug: plug)
    end

    test "paginates by incrementing startRow when full page of 25000 rows returned" do
      test_pid = self()
      page_count = :counters.new(1, [:atomics])

      paginating_plug = fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        count = :counters.get(page_count, 1) + 1
        :counters.put(page_count, 1, count)
        send(test_pid, {:request, count, conn, body})

        response_body =
          if count == 1 do
            full_page_response()
          else
            single_row_api_response()
          end

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, response_body)
      end

      assert {:ok, metrics} =
               GoogleSearchConsole.fetch_metrics(valid_integration(), http_plug: paginating_plug)

      assert_receive {:request, 1, _conn, first_body}
      assert_receive {:request, 2, _conn, second_body}

      {:ok, first_decoded} = Jason.decode(first_body)
      {:ok, second_decoded} = Jason.decode(second_body)

      assert first_decoded["startRow"] == 0
      assert second_decoded["startRow"] == 25_000

      assert length(metrics) > 25_000
    end

    test "stops pagination when page count reaches maximum of 10 pages" do
      page_count = :counters.new(1, [:atomics])

      max_pages_plug = fn conn ->
        :counters.add(page_count, 1, 1)

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, full_page_response())
      end

      capture_log(fn ->
        assert {:ok, _metrics} =
                 GoogleSearchConsole.fetch_metrics(valid_integration(), http_plug: max_pages_plug)
      end)

      assert :counters.get(page_count, 1) == 10
    end

    test "returns error :unauthorized on 401 response" do
      plug = build_stub_plug(401, Jason.encode!(%{"error" => "unauthorized"}))

      capture_log(fn ->
        assert {:error, :unauthorized} =
                 GoogleSearchConsole.fetch_metrics(valid_integration(), http_plug: plug)
      end)
    end

    test "returns error :insufficient_permissions on 403 response" do
      plug = build_stub_plug(403, Jason.encode!(%{"error" => "insufficient permissions"}))

      capture_log(fn ->
        assert {:error, :insufficient_permissions} =
                 GoogleSearchConsole.fetch_metrics(valid_integration(), http_plug: plug)
      end)
    end

    test "returns error :site_not_found on 404 response" do
      plug = build_stub_plug(404, Jason.encode!(%{"error" => "site not found"}))

      capture_log(fn ->
        assert {:error, :site_not_found} =
                 GoogleSearchConsole.fetch_metrics(valid_integration(), http_plug: plug)
      end)
    end

    test "returns error :bad_request on non-200 non-handled status" do
      plug = build_stub_plug(500, Jason.encode!(%{"error" => "internal server error"}))

      capture_log(fn ->
        assert {:error, :bad_request} =
                 GoogleSearchConsole.fetch_metrics(valid_integration(), http_plug: plug)
      end)
    end

    test "handles malformed JSON binary body with error :malformed_response" do
      malformed_plug = fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("text/plain")
        |> Plug.Conn.send_resp(200, "not valid json {{{")
      end

      assert {:error, :malformed_response} =
               GoogleSearchConsole.fetch_metrics(valid_integration(), http_plug: malformed_plug)
    end

    test "handles network exceptions with error {:network_error, message}" do
      error_plug = fn _conn ->
        raise %Req.TransportError{reason: :econnrefused}
      end

      capture_log(fn ->
        assert {:error, {:network_error, _message}} =
                 GoogleSearchConsole.fetch_metrics(valid_integration(), http_plug: error_plug)
      end)
    end

    test "accepts http_plug option for test injection" do
      plug = build_stub_plug(200, single_row_api_response())

      assert {:ok, metrics} =
               GoogleSearchConsole.fetch_metrics(valid_integration(), http_plug: plug)

      assert is_list(metrics)
    end
  end

  # ---------------------------------------------------------------------------
  # provider/0
  # ---------------------------------------------------------------------------

  describe "provider/0" do
    test "returns :google_search_console atom" do
      assert GoogleSearchConsole.provider() == :google_search_console
    end

    test "return value matches a valid Integration provider atom" do
      valid_providers = [
        :github,
        :gitlab,
        :bitbucket,
        :google,
        :google_ads,
        :facebook_ads,
        :google_analytics,
        :google_search_console,
        :google_business,
        :quickbooks
      ]

      assert GoogleSearchConsole.provider() in valid_providers
    end
  end

  # ---------------------------------------------------------------------------
  # required_scopes/0
  # ---------------------------------------------------------------------------

  describe "required_scopes/0" do
    test "returns list containing the webmasters.readonly scope URL" do
      scopes = GoogleSearchConsole.required_scopes()

      assert Enum.any?(scopes, fn scope ->
               String.contains?(scope, "webmasters.readonly")
             end)
    end

    test "returned scopes are strings not atoms" do
      scopes = GoogleSearchConsole.required_scopes()

      assert Enum.all?(scopes, &is_binary/1)
    end

    test "list contains exactly one scope" do
      scopes = GoogleSearchConsole.required_scopes()

      assert length(scopes) == 1
    end

    test "scope URL starts with https://" do
      scopes = GoogleSearchConsole.required_scopes()

      assert Enum.all?(scopes, fn scope -> String.starts_with?(scope, "https://") end)
    end
  end
end
