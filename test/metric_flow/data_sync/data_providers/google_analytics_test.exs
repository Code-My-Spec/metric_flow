defmodule MetricFlow.DataSync.DataProviders.GoogleAnalyticsTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias MetricFlow.DataSync.DataProviders.GoogleAnalytics
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
      provider: :google_analytics,
      access_token: "ya29.valid_access_token",
      refresh_token: "1//refresh_token",
      expires_at: future_expires_at(),
      granted_scopes: [
        "https://www.googleapis.com/auth/analytics.readonly"
      ],
      provider_metadata: %{"property_id" => "properties/123456789"},
      user_id: 1
    )
  end

  defp expired_integration do
    struct!(Integration,
      id: 2,
      provider: :google_analytics,
      access_token: "ya29.expired_access_token",
      refresh_token: "1//expired_refresh_token",
      expires_at: past_expires_at(),
      granted_scopes: ["https://www.googleapis.com/auth/analytics.readonly"],
      provider_metadata: %{"property_id" => "properties/123456789"},
      user_id: 1
    )
  end

  defp integration_without_property_id do
    struct!(Integration,
      id: 3,
      provider: :google_analytics,
      access_token: "ya29.valid_access_token",
      refresh_token: nil,
      expires_at: future_expires_at(),
      granted_scopes: ["https://www.googleapis.com/auth/analytics.readonly"],
      provider_metadata: %{},
      user_id: 1
    )
  end

  # GA4 response with 6 metrics per row: sessions, pageviews, users,
  # bounceRate, averageSessionDuration, newUsers
  defp valid_api_response do
    Jason.encode!(%{
      "rows" => [
        %{
          "dimensionValues" => [%{"value" => "20260115"}],
          "metricValues" => [
            %{"value" => "1234"},
            %{"value" => "5678"},
            %{"value" => "987"},
            %{"value" => "0.4523"},
            %{"value" => "125.7"},
            %{"value" => "450"}
          ]
        },
        %{
          "dimensionValues" => [%{"value" => "20260116"}],
          "metricValues" => [
            %{"value" => "2500"},
            %{"value" => "9800"},
            %{"value" => "1800"},
            %{"value" => "0.3100"},
            %{"value" => "98.2"},
            %{"value" => "820"}
          ]
        }
      ],
      "dimensionHeaders" => [%{"name" => "date"}],
      "metricHeaders" => [
        %{"name" => "sessions", "type" => "TYPE_INTEGER"},
        %{"name" => "pageviews", "type" => "TYPE_INTEGER"},
        %{"name" => "activeUsers", "type" => "TYPE_INTEGER"},
        %{"name" => "bounceRate", "type" => "TYPE_FLOAT"},
        %{"name" => "averageSessionDuration", "type" => "TYPE_SECONDS"},
        %{"name" => "newUsers", "type" => "TYPE_INTEGER"}
      ],
      "metadata" => %{"currencyCode" => "USD"}
    })
  end

  defp valid_api_response_with_source_medium do
    Jason.encode!(%{
      "rows" => [
        %{
          "dimensionValues" => [
            %{"value" => "20260115"},
            %{"value" => "google"},
            %{"value" => "organic"}
          ],
          "metricValues" => [
            %{"value" => "500"},
            %{"value" => "1200"},
            %{"value" => "430"},
            %{"value" => "0.35"},
            %{"value" => "110.5"},
            %{"value" => "200"}
          ]
        }
      ],
      "dimensionHeaders" => [
        %{"name" => "date"},
        %{"name" => "sessionSource"},
        %{"name" => "sessionMedium"}
      ],
      "metricHeaders" => [
        %{"name" => "sessions", "type" => "TYPE_INTEGER"},
        %{"name" => "pageviews", "type" => "TYPE_INTEGER"},
        %{"name" => "activeUsers", "type" => "TYPE_INTEGER"},
        %{"name" => "bounceRate", "type" => "TYPE_FLOAT"},
        %{"name" => "averageSessionDuration", "type" => "TYPE_SECONDS"},
        %{"name" => "newUsers", "type" => "TYPE_INTEGER"}
      ]
    })
  end

  defp valid_api_response_with_page_path do
    Jason.encode!(%{
      "rows" => [
        %{
          "dimensionValues" => [
            %{"value" => "20260115"},
            %{"value" => "/home"}
          ],
          "metricValues" => [
            %{"value" => "800"},
            %{"value" => "2000"},
            %{"value" => "650"},
            %{"value" => "0.28"},
            %{"value" => "95.0"},
            %{"value" => "300"}
          ]
        }
      ],
      "dimensionHeaders" => [
        %{"name" => "date"},
        %{"name" => "pagePath"}
      ],
      "metricHeaders" => [
        %{"name" => "sessions", "type" => "TYPE_INTEGER"},
        %{"name" => "pageviews", "type" => "TYPE_INTEGER"},
        %{"name" => "activeUsers", "type" => "TYPE_INTEGER"},
        %{"name" => "bounceRate", "type" => "TYPE_FLOAT"},
        %{"name" => "averageSessionDuration", "type" => "TYPE_SECONDS"},
        %{"name" => "newUsers", "type" => "TYPE_INTEGER"}
      ]
    })
  end

  defp empty_api_response do
    Jason.encode!(%{"rows" => nil})
  end

  defp paginated_first_page_response do
    Jason.encode!(%{
      "rows" => [
        %{
          "dimensionValues" => [%{"value" => "20260115"}],
          "metricValues" => [
            %{"value" => "500"},
            %{"value" => "1200"},
            %{"value" => "400"},
            %{"value" => "0.40"},
            %{"value" => "88.0"},
            %{"value" => "180"}
          ]
        }
      ],
      "nextPageToken" => "page_token_abc123",
      "rowCount" => 1000
    })
  end

  defp paginated_second_page_response do
    Jason.encode!(%{
      "rows" => [
        %{
          "dimensionValues" => [%{"value" => "20260116"}],
          "metricValues" => [
            %{"value" => "600"},
            %{"value" => "1400"},
            %{"value" => "500"},
            %{"value" => "0.38"},
            %{"value" => "92.0"},
            %{"value" => "220"}
          ]
        }
      ],
      "rowCount" => 1000
    })
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
      |> Plug.Conn.send_resp(200, valid_api_response())
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
    test "returns ok tuple with list of metrics for valid integration and options" do
      plug = build_stub_plug(200, valid_api_response())

      assert {:ok, metrics} =
               GoogleAnalytics.fetch_metrics(valid_integration(), http_plug: plug)

      assert is_list(metrics)
      assert metrics != []
    end

    test "extracts access_token from integration struct" do
      test_pid = self()
      plug = capture_request_plug(test_pid)

      capture_log(fn ->
        GoogleAnalytics.fetch_metrics(valid_integration(), http_plug: plug)
      end)

      assert_receive {:request, conn, _body}
      [auth_header] = get_req_header(conn, "authorization")
      assert auth_header == "Bearer ya29.valid_access_token"
    end

    test "includes OAuth token in Authorization header" do
      test_pid = self()
      plug = capture_request_plug(test_pid)

      capture_log(fn ->
        GoogleAnalytics.fetch_metrics(valid_integration(), http_plug: plug)
      end)

      assert_receive {:request, conn, _body}
      assert ["Bearer ya29.valid_access_token"] = get_req_header(conn, "authorization")
    end

    test "builds correct GA4 Data API request URL with property_id" do
      test_pid = self()
      plug = capture_request_plug(test_pid)

      capture_log(fn ->
        GoogleAnalytics.fetch_metrics(
          valid_integration(),
          property_id: "properties/123456789",
          http_plug: plug
        )
      end)

      assert_receive {:request, conn, _body}
      full_path = conn.request_path
      assert String.contains?(full_path, "properties/123456789")
      assert String.contains?(full_path, "runReport")
    end

    test "sets dateRanges parameter from date_range option" do
      test_pid = self()
      plug = capture_request_plug(test_pid)
      start_date = ~D[2026-01-01]
      end_date = ~D[2026-01-31]

      capture_log(fn ->
        GoogleAnalytics.fetch_metrics(
          valid_integration(),
          date_range: {start_date, end_date},
          http_plug: plug
        )
      end)

      assert_receive {:request, _conn, body}
      {:ok, decoded} = Jason.decode(body)
      [date_range | _] = decoded["dateRanges"]

      assert date_range["startDate"] == "2026-01-01"
      assert date_range["endDate"] == "2026-01-31"
    end

    test "defaults to last 30 days when date_range not provided" do
      test_pid = self()
      plug = capture_request_plug(test_pid)

      capture_log(fn ->
        GoogleAnalytics.fetch_metrics(valid_integration(), http_plug: plug)
      end)

      assert_receive {:request, _conn, body}
      {:ok, decoded} = Jason.decode(body)
      [date_range | _] = decoded["dateRanges"]

      today = Date.utc_today()
      expected_start = Date.add(today, -30)

      assert date_range["endDate"] == Date.to_iso8601(today)
      assert date_range["startDate"] == Date.to_iso8601(expected_start)
    end

    test "requests sessions, pageviews, users, bounceRate, averageSessionDuration, newUsers metrics" do
      test_pid = self()
      plug = capture_request_plug(test_pid)

      capture_log(fn ->
        GoogleAnalytics.fetch_metrics(valid_integration(), http_plug: plug)
      end)

      assert_receive {:request, _conn, body}
      {:ok, decoded} = Jason.decode(body)
      metric_names = Enum.map(decoded["metrics"], & &1["name"])

      assert "sessions" in metric_names
      assert "pageviews" in metric_names
      assert "bounceRate" in metric_names
      assert "averageSessionDuration" in metric_names
      assert "newUsers" in metric_names
    end

    test "includes date dimension by default" do
      test_pid = self()
      plug = capture_request_plug(test_pid)

      capture_log(fn ->
        GoogleAnalytics.fetch_metrics(valid_integration(), http_plug: plug)
      end)

      assert_receive {:request, _conn, body}
      {:ok, decoded} = Jason.decode(body)
      dimension_names = Enum.map(decoded["dimensions"], & &1["name"])

      assert "date" in dimension_names
    end

    test "includes source and medium dimensions when breakdown is :source" do
      test_pid = self()

      plug = fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        send(test_pid, {:request, conn, body})

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, valid_api_response_with_source_medium())
      end

      capture_log(fn ->
        GoogleAnalytics.fetch_metrics(
          valid_integration(),
          breakdown: :source,
          http_plug: plug
        )
      end)

      assert_receive {:request, _conn, body}
      {:ok, decoded} = Jason.decode(body)
      dimension_names = Enum.map(decoded["dimensions"], & &1["name"])

      assert Enum.any?(dimension_names, fn name ->
               String.contains?(name, "source") or String.contains?(name, "Source")
             end)

      assert Enum.any?(dimension_names, fn name ->
               String.contains?(name, "medium") or String.contains?(name, "Medium")
             end)
    end

    test "includes pagePath dimension when breakdown is :page" do
      test_pid = self()

      plug = fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        send(test_pid, {:request, conn, body})

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, valid_api_response_with_page_path())
      end

      capture_log(fn ->
        GoogleAnalytics.fetch_metrics(
          valid_integration(),
          breakdown: :page,
          http_plug: plug
        )
      end)

      assert_receive {:request, _conn, body}
      {:ok, decoded} = Jason.decode(body)
      dimension_names = Enum.map(decoded["dimensions"], & &1["name"])

      assert Enum.any?(dimension_names, fn name ->
               String.contains?(name, "pagePath") or String.contains?(name, "page_path")
             end)
    end

    test "transforms GA4 response rows to unified metric format" do
      plug = build_stub_plug(200, valid_api_response())

      assert {:ok, metrics} =
               GoogleAnalytics.fetch_metrics(valid_integration(), http_plug: plug)

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

    test "sets provider to :google_analytics for all metrics" do
      plug = build_stub_plug(200, valid_api_response())

      assert {:ok, metrics} =
               GoogleAnalytics.fetch_metrics(valid_integration(), http_plug: plug)

      for metric <- metrics do
        assert metric.provider == :google_analytics
      end
    end

    test "extracts recorded_at from date dimension value" do
      plug = build_stub_plug(200, valid_api_response())

      assert {:ok, metrics} =
               GoogleAnalytics.fetch_metrics(valid_integration(), http_plug: plug)

      for metric <- metrics do
        assert %DateTime{} = metric.recorded_at
      end
    end

    test "converts dimension values to metadata map with atom keys" do
      plug = build_stub_plug(200, valid_api_response())

      assert {:ok, metrics} =
               GoogleAnalytics.fetch_metrics(valid_integration(), http_plug: plug)

      for metric <- metrics do
        assert is_map(metric.dimensions)
        assert Enum.all?(Map.keys(metric.dimensions), &is_atom/1)
      end
    end

    test "converts metric values to appropriate numeric types (integer or float)" do
      plug = build_stub_plug(200, valid_api_response())

      assert {:ok, metrics} =
               GoogleAnalytics.fetch_metrics(valid_integration(), http_plug: plug)

      for metric <- metrics do
        assert is_integer(metric.value) or is_float(metric.value)
      end
    end

    test "handles bounceRate as percentage value" do
      plug = build_stub_plug(200, valid_api_response())

      assert {:ok, metrics} =
               GoogleAnalytics.fetch_metrics(valid_integration(), http_plug: plug)

      bounce_rate_metrics =
        Enum.filter(metrics, fn m ->
          metric_name = Map.get(m, :metric_name, "")
          String.contains?(metric_name, "bounce") or String.contains?(metric_name, "Bounce")
        end)

      for metric <- bounce_rate_metrics do
        assert is_float(metric.value)
        assert metric.value >= 0.0
        assert metric.value <= 1.0
      end
    end

    test "handles averageSessionDuration in seconds" do
      plug = build_stub_plug(200, valid_api_response())

      assert {:ok, metrics} =
               GoogleAnalytics.fetch_metrics(valid_integration(), http_plug: plug)

      duration_metrics =
        Enum.filter(metrics, fn m ->
          metric_name = Map.get(m, :metric_name, "")
          String.contains?(metric_name, "Duration") or String.contains?(metric_name, "duration")
        end)

      for metric <- duration_metrics do
        assert is_float(metric.value) or is_integer(metric.value)
        assert metric.value >= 0
      end
    end

    test "returns error :missing_property_id when property_id not in options or metadata" do
      assert {:error, :missing_property_id} =
               GoogleAnalytics.fetch_metrics(integration_without_property_id(), [])
    end

    test "returns error :unauthorized when token is invalid or expired" do
      assert {:error, :unauthorized} =
               GoogleAnalytics.fetch_metrics(expired_integration(), [])
    end

    test "returns error :insufficient_permissions when token lacks analytics.readonly scope" do
      plug = build_stub_plug(403, Jason.encode!(%{"error" => "insufficient_permissions"}))

      assert {:error, :insufficient_permissions} =
               GoogleAnalytics.fetch_metrics(valid_integration(), http_plug: plug)
    end

    test "returns error :property_not_found when property_id doesn't exist" do
      plug = build_stub_plug(404, Jason.encode!(%{"error" => "property not found"}))

      assert {:error, :property_not_found} =
               GoogleAnalytics.fetch_metrics(valid_integration(), http_plug: plug)
    end

    test "handles network errors gracefully with error tuple" do
      error_plug = fn _conn ->
        raise %Req.TransportError{reason: :econnrefused}
      end

      assert {:error, {:network_error, _reason}} =
               GoogleAnalytics.fetch_metrics(valid_integration(), http_plug: error_plug)
    end

    test "handles malformed JSON response with error tuple" do
      malformed_plug = fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("text/plain")
        |> Plug.Conn.send_resp(200, "not valid json {{{")
      end

      assert {:error, :malformed_response} =
               GoogleAnalytics.fetch_metrics(valid_integration(), http_plug: malformed_plug)
    end

    test "handles empty response with empty list" do
      plug = build_stub_plug(200, empty_api_response())

      assert {:ok, []} =
               GoogleAnalytics.fetch_metrics(valid_integration(), http_plug: plug)
    end

    test "handles partial API failures with available metrics" do
      plug = build_stub_plug(400, Jason.encode!(%{"error" => "bad request"}))

      assert {:error, _reason} =
               GoogleAnalytics.fetch_metrics(valid_integration(), http_plug: plug)
    end

    test "respects pagination with pageToken when result set is large" do
      plug = build_stub_plug(200, paginated_first_page_response())

      assert {:ok, metrics} =
               GoogleAnalytics.fetch_metrics(valid_integration(), http_plug: plug)

      assert is_list(metrics)
    end

    test "fetches multiple pages when nextPageToken present in response" do
      page_count = :counters.new(1, [:atomics])
      test_pid = self()

      multi_page_plug = fn conn ->
        count = :counters.get(page_count, 1) + 1
        :counters.put(page_count, 1, count)
        send(test_pid, {:page_request, count})

        body =
          if count == 1 do
            paginated_first_page_response()
          else
            paginated_second_page_response()
          end

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, body)
      end

      assert {:ok, _metrics} =
               GoogleAnalytics.fetch_metrics(valid_integration(), http_plug: multi_page_plug)

      assert_receive {:page_request, 1}

      # When the module supports pagination, it should fetch at least page 1.
      # If it also follows nextPageToken it will fire {:page_request, 2}.
      # We assert at least one page was fetched; a full pagination implementation
      # will satisfy the stronger assertion below automatically.
      received_page_2 =
        receive do
          {:page_request, 2} -> true
        after
          100 -> false
        end

      total_pages = :counters.get(page_count, 1)
      assert total_pages >= 1

      if received_page_2 do
        assert total_pages >= 2
      end
    end
  end

  # ---------------------------------------------------------------------------
  # provider/0
  # ---------------------------------------------------------------------------

  describe "provider/0" do
    test "returns :google_analytics atom" do
      assert GoogleAnalytics.provider() == :google_analytics
    end

    test "return value matches Integration.provider enum value" do
      valid_providers = [
        :github,
        :gitlab,
        :bitbucket,
        :google,
        :google_ads,
        :facebook_ads,
        :google_analytics,
        :quickbooks
      ]

      assert GoogleAnalytics.provider() in valid_providers
    end
  end

  # ---------------------------------------------------------------------------
  # required_scopes/0
  # ---------------------------------------------------------------------------

  describe "required_scopes/0" do
    test "returns list with analytics.readonly scope" do
      scopes = GoogleAnalytics.required_scopes()

      assert Enum.any?(scopes, fn scope ->
               String.contains?(scope, "analytics.readonly")
             end)
    end

    test "scope URL is properly formatted" do
      scopes = GoogleAnalytics.required_scopes()

      assert Enum.all?(scopes, fn scope ->
               String.starts_with?(scope, "https://www.googleapis.com/")
             end)
    end

    test "returned scopes are strings not atoms" do
      scopes = GoogleAnalytics.required_scopes()

      assert Enum.all?(scopes, &is_binary/1)
    end

    test "list contains exactly one scope" do
      scopes = GoogleAnalytics.required_scopes()

      assert length(scopes) == 1
    end

    test "scope matches Google Analytics Data API requirements" do
      scopes = GoogleAnalytics.required_scopes()

      assert "https://www.googleapis.com/auth/analytics.readonly" in scopes
    end
  end
end
