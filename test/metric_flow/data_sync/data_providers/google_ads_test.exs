defmodule MetricFlow.DataSync.DataProviders.GoogleAdsTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog
  import ReqCassette

  alias MetricFlow.DataSync.DataProviders.GoogleAds
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
      provider: :google_ads,
      access_token: "ya29.valid_google_ads_token",
      refresh_token: "1//refresh_token",
      expires_at: future_expires_at(),
      granted_scopes: ["https://www.googleapis.com/auth/adwords"],
      provider_metadata: %{"customer_id" => "1234567890"},
      user_id: 1
    )
  end

  defp expired_integration do
    struct!(Integration,
      id: 2,
      provider: :google_ads,
      access_token: "ya29.expired_access_token",
      refresh_token: "1//expired_refresh_token",
      expires_at: past_expires_at(),
      granted_scopes: ["https://www.googleapis.com/auth/adwords"],
      provider_metadata: %{"customer_id" => "1234567890"},
      user_id: 1
    )
  end

  defp integration_without_customer_id do
    struct!(Integration,
      id: 3,
      provider: :google_ads,
      access_token: "ya29.valid_access_token",
      refresh_token: nil,
      expires_at: future_expires_at(),
      granted_scopes: ["https://www.googleapis.com/auth/adwords"],
      provider_metadata: %{},
      user_id: 1
    )
  end

  # A single campaign row in the Google Ads searchStream response format.
  # cost_micros: 5_000_000 = $5.00, ctr: 0.05 = 5%, average_cpc: 500_000 = $0.50
  defp valid_api_response do
    Jason.encode!([
      %{
        "results" => [
          %{
            "campaign" => %{"name" => "Summer Sale Campaign"},
            "adGroup" => %{"name" => "Ad Group 1"},
            "metrics" => %{
              "impressions" => "10000",
              "clicks" => "500",
              "costMicros" => "5000000",
              "conversions" => "25.0",
              "ctr" => 0.05,
              "averageCpc" => "500000",
              "conversionsValue" => "250.0"
            },
            "segments" => %{"date" => "2026-01-15"}
          },
          %{
            "campaign" => %{"name" => "Winter Sale Campaign"},
            "adGroup" => %{"name" => "Ad Group 2"},
            "metrics" => %{
              "impressions" => "8000",
              "clicks" => "320",
              "costMicros" => "3200000",
              "conversions" => "16.0",
              "ctr" => 0.04,
              "averageCpc" => "400000",
              "conversionsValue" => "160.0"
            },
            "segments" => %{"date" => "2026-01-16"}
          }
        ]
      }
    ])
  end

  defp empty_api_response do
    Jason.encode!([%{"results" => []}])
  end

  defp zero_impressions_response do
    Jason.encode!([
      %{
        "results" => [
          %{
            "campaign" => %{"name" => "Paused Campaign"},
            "adGroup" => nil,
            "metrics" => %{
              "impressions" => "0",
              "clicks" => "0",
              "costMicros" => "0",
              "conversions" => "0.0",
              "ctr" => 0.0,
              "averageCpc" => "0",
              "conversionsValue" => "0.0"
            },
            "segments" => %{"date" => "2026-01-15"}
          }
        ]
      }
    ])
  end

  defp null_dimensions_response do
    Jason.encode!([
      %{
        "results" => [
          %{
            "campaign" => nil,
            "adGroup" => nil,
            "metrics" => %{
              "impressions" => "1000",
              "clicks" => "50",
              "costMicros" => "1000000",
              "conversions" => "5.0",
              "ctr" => 0.05,
              "averageCpc" => "200000",
              "conversionsValue" => "50.0"
            },
            "segments" => %{"date" => "2026-01-15"}
          }
        ]
      }
    ])
  end

  defp paginated_first_page_response do
    Jason.encode!([
      %{
        "results" => [
          %{
            "campaign" => %{"name" => "Page 1 Campaign"},
            "adGroup" => %{"name" => "Ad Group A"},
            "metrics" => %{
              "impressions" => "5000",
              "clicks" => "200",
              "costMicros" => "2000000",
              "conversions" => "10.0",
              "ctr" => 0.04,
              "averageCpc" => "100000",
              "conversionsValue" => "100.0"
            },
            "segments" => %{"date" => "2026-01-15"}
          }
        ],
        "nextPageToken" => "some_page_token_abc123"
      }
    ])
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
               GoogleAds.fetch_metrics(valid_integration(), http_plug: plug)

      assert is_list(metrics)
      assert metrics != []
    end

    test "extracts access_token from integration struct" do
      test_pid = self()
      plug = capture_request_plug(test_pid)

      capture_log(fn ->
        GoogleAds.fetch_metrics(valid_integration(), http_plug: plug)
      end)

      assert_receive {:request, conn, _body}
      assert ["Bearer ya29.valid_google_ads_token"] = get_req_header(conn, "authorization")
    end

    test "includes OAuth token in Authorization header with Bearer prefix" do
      test_pid = self()
      plug = capture_request_plug(test_pid)

      capture_log(fn ->
        GoogleAds.fetch_metrics(valid_integration(), http_plug: plug)
      end)

      assert_receive {:request, conn, _body}
      [auth_header] = get_req_header(conn, "authorization")
      assert String.starts_with?(auth_header, "Bearer ")
    end

    test "includes developer-token header in request" do
      test_pid = self()
      plug = capture_request_plug(test_pid)

      capture_log(fn ->
        GoogleAds.fetch_metrics(valid_integration(), http_plug: plug)
      end)

      assert_receive {:request, conn, _body}
      assert get_req_header(conn, "developer-token") != []
    end

    test "builds correct Google Ads API searchStream URL with customer_id" do
      test_pid = self()
      plug = capture_request_plug(test_pid)

      capture_log(fn ->
        GoogleAds.fetch_metrics(
          valid_integration(),
          customer_id: "1234567890",
          http_plug: plug
        )
      end)

      assert_receive {:request, conn, _body}
      full_path = conn.request_path
      assert String.contains?(full_path, "1234567890")
      assert String.contains?(full_path, "googleAds:searchStream")
    end

    test "sets customer_id from options when provided" do
      test_pid = self()
      plug = capture_request_plug(test_pid)

      integration_without_metadata =
        struct!(Integration,
          id: 4,
          provider: :google_ads,
          access_token: "ya29.token",
          expires_at: future_expires_at(),
          provider_metadata: %{},
          user_id: 1
        )

      capture_log(fn ->
        GoogleAds.fetch_metrics(
          integration_without_metadata,
          customer_id: "9999888877",
          http_plug: plug
        )
      end)

      assert_receive {:request, conn, _body}
      assert String.contains?(conn.request_path, "9999888877")
    end

    test "sets customer_id from provider_metadata when not in options" do
      test_pid = self()
      plug = capture_request_plug(test_pid)

      capture_log(fn ->
        GoogleAds.fetch_metrics(valid_integration(), http_plug: plug)
      end)

      assert_receive {:request, conn, _body}
      assert String.contains?(conn.request_path, "1234567890")
    end

    test "builds valid GAQL query string" do
      test_pid = self()
      plug = capture_request_plug(test_pid)

      capture_log(fn ->
        GoogleAds.fetch_metrics(valid_integration(), http_plug: plug)
      end)

      assert_receive {:request, _conn, body}
      {:ok, decoded} = Jason.decode(body)
      query = decoded["query"]
      assert is_binary(query)
      assert String.contains?(query, "SELECT")
      assert String.contains?(query, "FROM")
      assert String.contains?(query, "WHERE")
    end

    test "includes impressions, clicks, cost_micros, conversions in SELECT clause" do
      test_pid = self()
      plug = capture_request_plug(test_pid)

      capture_log(fn ->
        GoogleAds.fetch_metrics(valid_integration(), http_plug: plug)
      end)

      assert_receive {:request, _conn, body}
      {:ok, decoded} = Jason.decode(body)
      query = decoded["query"]
      assert String.contains?(query, "metrics.impressions")
      assert String.contains?(query, "metrics.clicks")
      assert String.contains?(query, "metrics.cost_micros")
      assert String.contains?(query, "metrics.conversions")
    end

    test "includes ctr, average_cpc, conversions_value in SELECT clause" do
      test_pid = self()
      plug = capture_request_plug(test_pid)

      capture_log(fn ->
        GoogleAds.fetch_metrics(valid_integration(), http_plug: plug)
      end)

      assert_receive {:request, _conn, body}
      {:ok, decoded} = Jason.decode(body)
      query = decoded["query"]
      assert String.contains?(query, "metrics.ctr")
      assert String.contains?(query, "metrics.average_cpc")
      assert String.contains?(query, "metrics.conversions_value")
    end

    test "includes campaign.name and segments.date dimensions by default" do
      test_pid = self()
      plug = capture_request_plug(test_pid)

      capture_log(fn ->
        GoogleAds.fetch_metrics(valid_integration(), http_plug: plug)
      end)

      assert_receive {:request, _conn, body}
      {:ok, decoded} = Jason.decode(body)
      query = decoded["query"]
      assert String.contains?(query, "campaign.name")
      assert String.contains?(query, "segments.date")
    end

    test "includes ad_group.name dimension when breakdown is :ad_group" do
      test_pid = self()
      plug = capture_request_plug(test_pid)

      capture_log(fn ->
        GoogleAds.fetch_metrics(valid_integration(), breakdown: :ad_group, http_plug: plug)
      end)

      assert_receive {:request, _conn, body}
      {:ok, decoded} = Jason.decode(body)
      query = decoded["query"]
      assert String.contains?(query, "ad_group.name")
    end

    test "sets WHERE clause with date range using segments.date BETWEEN" do
      test_pid = self()
      plug = capture_request_plug(test_pid)

      capture_log(fn ->
        GoogleAds.fetch_metrics(valid_integration(), http_plug: plug)
      end)

      assert_receive {:request, _conn, body}
      {:ok, decoded} = Jason.decode(body)
      query = decoded["query"]
      assert String.contains?(query, "segments.date BETWEEN")
    end

    test "defaults to last 548 days when date_range not provided" do
      test_pid = self()
      plug = capture_request_plug(test_pid)

      capture_log(fn ->
        GoogleAds.fetch_metrics(valid_integration(), http_plug: plug)
      end)

      assert_receive {:request, _conn, body}
      {:ok, decoded} = Jason.decode(body)
      query = decoded["query"]

      today = Date.utc_today()
      expected_start = Date.add(today, -548)

      assert String.contains?(query, Date.to_iso8601(today))
      assert String.contains?(query, Date.to_iso8601(expected_start))
    end

    test "formats dates as YYYY-MM-DD in GAQL query" do
      test_pid = self()
      plug = capture_request_plug(test_pid)

      start_date = ~D[2026-01-01]
      end_date = ~D[2026-01-31]

      capture_log(fn ->
        GoogleAds.fetch_metrics(
          valid_integration(),
          date_range: {start_date, end_date},
          http_plug: plug
        )
      end)

      assert_receive {:request, _conn, body}
      {:ok, decoded} = Jason.decode(body)
      query = decoded["query"]
      assert String.contains?(query, "2026-01-01")
      assert String.contains?(query, "2026-01-31")
    end

    test "transforms Google Ads API response rows to unified metric format" do
      plug = build_stub_plug(200, valid_api_response())

      assert {:ok, metrics} = GoogleAds.fetch_metrics(valid_integration(), http_plug: plug)

      assert Enum.all?(metrics, &is_map/1)
    end

    test "sets provider to :google_ads for all metrics" do
      plug = build_stub_plug(200, valid_api_response())

      assert {:ok, metrics} = GoogleAds.fetch_metrics(valid_integration(), http_plug: plug)

      for metric <- metrics do
        assert metric.provider == :google_ads
      end
    end

    test "extracts recorded_at from segments.date value" do
      plug = build_stub_plug(200, valid_api_response())

      assert {:ok, metrics} = GoogleAds.fetch_metrics(valid_integration(), http_plug: plug)

      for metric <- metrics do
        assert %DateTime{} = metric.recorded_at
      end
    end

    test "converts cost_micros to dollars by dividing by 1,000,000" do
      cost_micros_response =
        Jason.encode!([
          %{
            "results" => [
              %{
                "campaign" => %{"name" => "Test Campaign"},
                "adGroup" => nil,
                "metrics" => %{
                  "impressions" => "1000",
                  "clicks" => "50",
                  "costMicros" => "5000000",
                  "conversions" => "0.0",
                  "ctr" => 0.05,
                  "averageCpc" => "100000",
                  "conversionsValue" => "0.0"
                },
                "segments" => %{"date" => "2026-01-15"}
              }
            ]
          }
        ])

      plug = build_stub_plug(200, cost_micros_response)

      assert {:ok, metrics} = GoogleAds.fetch_metrics(valid_integration(), http_plug: plug)

      cost_metric = Enum.find(metrics, fn m -> m.metric_name == "cost" end)
      assert cost_metric != nil
      assert cost_metric.value == 5.0
    end

    test "extracts ctr as percentage value" do
      plug = build_stub_plug(200, valid_api_response())

      assert {:ok, metrics} = GoogleAds.fetch_metrics(valid_integration(), http_plug: plug)

      ctr_metric = Enum.find(metrics, fn m -> m.metric_name == "ctr" end)
      assert ctr_metric != nil
      assert is_float(ctr_metric.value)
    end

    test "extracts average_cpc in dollars" do
      plug = build_stub_plug(200, valid_api_response())

      assert {:ok, metrics} = GoogleAds.fetch_metrics(valid_integration(), http_plug: plug)

      cpc_metric = Enum.find(metrics, fn m -> m.metric_name == "average_cpc" end)
      assert cpc_metric != nil
      assert is_float(cpc_metric.value)
    end

    test "converts dimension values to metadata map with atom keys" do
      plug = build_stub_plug(200, valid_api_response())

      assert {:ok, metrics} = GoogleAds.fetch_metrics(valid_integration(), http_plug: plug)

      for metric <- metrics do
        assert is_map(metric.metadata)
        assert Map.keys(metric.metadata) |> Enum.all?(&is_atom/1)
      end
    end

    test "includes campaign_name in metadata" do
      plug = build_stub_plug(200, valid_api_response())

      assert {:ok, metrics} = GoogleAds.fetch_metrics(valid_integration(), http_plug: plug)

      for metric <- metrics do
        assert Map.has_key?(metric.metadata, :campaign_name)
      end
    end

    test "includes ad_group_name in metadata when present" do
      plug = build_stub_plug(200, valid_api_response())

      assert {:ok, metrics} = GoogleAds.fetch_metrics(valid_integration(), http_plug: plug)

      for metric <- metrics do
        assert Map.has_key?(metric.metadata, :ad_group_name)
      end
    end

    test "converts metric values to appropriate numeric types (integer or float)" do
      plug = build_stub_plug(200, valid_api_response())

      assert {:ok, metrics} = GoogleAds.fetch_metrics(valid_integration(), http_plug: plug)

      for metric <- metrics do
        assert is_integer(metric.value) or is_float(metric.value)
      end
    end

    test "handles conversions_value as float" do
      plug = build_stub_plug(200, valid_api_response())

      assert {:ok, metrics} = GoogleAds.fetch_metrics(valid_integration(), http_plug: plug)

      conversions_value_metric =
        Enum.find(metrics, fn m -> m.metric_name == "conversions_value" end)

      assert conversions_value_metric != nil
      assert is_float(conversions_value_metric.value)
    end

    test "returns error :missing_customer_id when customer_id not in options or metadata" do
      assert {:error, :missing_customer_id} =
               GoogleAds.fetch_metrics(integration_without_customer_id(), [])
    end

    test "returns error :unauthorized when token is invalid or expired" do
      assert {:error, :unauthorized} =
               GoogleAds.fetch_metrics(expired_integration(), [])
    end

    test "returns error :insufficient_permissions when token lacks adwords scope" do
      plug =
        build_stub_plug(403, Jason.encode!(%{"error" => %{"message" => "insufficient_permissions"}}))

      assert {:error, :insufficient_permissions} =
               GoogleAds.fetch_metrics(valid_integration(), http_plug: plug)
    end

    test "returns error :customer_not_found when customer_id doesn't exist or user lacks access" do
      plug =
        build_stub_plug(404, Jason.encode!(%{"error" => %{"message" => "customer not found"}}))

      assert {:error, :customer_not_found} =
               GoogleAds.fetch_metrics(valid_integration(), http_plug: plug)
    end

    test "returns error with GAQL details when query syntax is invalid" do
      plug =
        build_stub_plug(
          400,
          Jason.encode!(%{
            "error" => %{
              "message" => "GAQL syntax error: unexpected token at position 42",
              "code" => 400
            }
          })
        )

      assert {:error, _gaql_error_details} =
               GoogleAds.fetch_metrics(valid_integration(), http_plug: plug)
    end

    test "handles network errors gracefully with error tuple" do
      error_plug = fn _conn ->
        raise %Req.TransportError{reason: :econnrefused}
      end

      assert {:error, {:network_error, _reason}} =
               GoogleAds.fetch_metrics(valid_integration(), http_plug: error_plug)
    end

    test "handles malformed JSON response with error tuple" do
      malformed_plug = fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("text/plain")
        |> Plug.Conn.send_resp(200, "not valid json {{{")
      end

      assert {:error, :malformed_response} =
               GoogleAds.fetch_metrics(valid_integration(), http_plug: malformed_plug)
    end

    test "handles empty response with empty list" do
      plug = build_stub_plug(200, empty_api_response())

      assert {:ok, []} = GoogleAds.fetch_metrics(valid_integration(), http_plug: plug)
    end

    test "handles API rate limiting with error :rate_limited" do
      plug =
        build_stub_plug(
          429,
          Jason.encode!(%{"error" => %{"message" => "rate limit exceeded"}})
        )

      assert {:error, :rate_limited} =
               GoogleAds.fetch_metrics(valid_integration(), http_plug: plug)
    end

    test "respects pagination with pageToken when result set is large" do
      plug = build_stub_plug(200, paginated_first_page_response())

      assert {:ok, metrics} = GoogleAds.fetch_metrics(valid_integration(), http_plug: plug)

      assert is_list(metrics)
      assert metrics != []
    end

    test "fetches multiple pages when nextPageToken present in response" do
      page_count = :counters.new(1, [:atomics])
      test_pid = self()

      multi_page_plug = fn conn ->
        count = :counters.get(page_count, 1) + 1
        :counters.put(page_count, 1, count)
        send(test_pid, {:page_request, count})

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        {:ok, decoded} = Jason.decode(body)

        response =
          if Map.get(decoded, "pageToken") == nil do
            paginated_first_page_response()
          else
            valid_api_response()
          end

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, response)
      end

      assert {:ok, _metrics} =
               GoogleAds.fetch_metrics(valid_integration(), http_plug: multi_page_plug)

      assert_receive {:page_request, 1}
      assert_receive {:page_request, 2}
    end

    test "includes customer_id in each metric's metadata" do
      plug = build_stub_plug(200, valid_api_response())

      assert {:ok, metrics} =
               GoogleAds.fetch_metrics(valid_integration(),
                 customer_id: "1234567890",
                 http_plug: plug
               )

      for metric <- metrics do
        assert Map.has_key?(metric.metadata, :customer_id)
        assert metric.metadata.customer_id == "1234567890"
      end
    end

    test "handles campaigns with zero impressions or clicks" do
      plug = build_stub_plug(200, zero_impressions_response())

      assert {:ok, metrics} = GoogleAds.fetch_metrics(valid_integration(), http_plug: plug)

      impressions_metric = Enum.find(metrics, fn m -> m.metric_name == "impressions" end)
      assert impressions_metric != nil
      assert impressions_metric.value == 0
    end

    test "handles null or missing dimension values gracefully" do
      plug = build_stub_plug(200, null_dimensions_response())

      assert {:ok, metrics} = GoogleAds.fetch_metrics(valid_integration(), http_plug: plug)

      assert is_list(metrics)
    end
  end

  # ---------------------------------------------------------------------------
  # provider/0
  # ---------------------------------------------------------------------------

  describe "provider/0" do
    test "returns :google_ads atom" do
      assert GoogleAds.provider() == :google_ads
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

      assert GoogleAds.provider() in valid_providers
    end
  end

  # ---------------------------------------------------------------------------
  # required_scopes/0
  # ---------------------------------------------------------------------------

  describe "required_scopes/0" do
    test "returns list with adwords scope" do
      scopes = GoogleAds.required_scopes()

      assert Enum.any?(scopes, fn scope ->
               String.contains?(scope, "adwords")
             end)
    end

    test "scope URL is properly formatted" do
      scopes = GoogleAds.required_scopes()

      assert Enum.all?(scopes, fn scope ->
               String.starts_with?(scope, "https://")
             end)
    end

    test "returned scopes are strings not atoms" do
      scopes = GoogleAds.required_scopes()

      assert Enum.all?(scopes, &is_binary/1)
    end

    test "list contains exactly one scope" do
      scopes = GoogleAds.required_scopes()

      assert length(scopes) == 1
    end

    test "scope matches Google Ads API requirements" do
      scopes = GoogleAds.required_scopes()

      assert "https://www.googleapis.com/auth/adwords" in scopes
    end
  end

  # ---------------------------------------------------------------------------
  # Cassette integration tests — real Google Ads API traffic
  # ---------------------------------------------------------------------------

  describe "fetch_metrics/2 with cassette" do
    @describetag :integration

    import MetricFlowTest.CassetteFixtures

    setup do
      case google_ads_integration() do
        nil -> {:ok, skip: true}
        integration -> {:ok, integration: integration}
      end
    end

    test "fetches real campaign metrics from Google Ads API", context do
      if context[:skip], do: flunk("GOOGLE_ADS_TEST_CUSTOMER_ID not set in .env.test")

      capture_log(fn ->
        with_cassette "google_ads_fetch_metrics", cassette_opts("google_ads_fetch_metrics"), fn plug ->
          assert {:ok, metrics} =
                   GoogleAds.fetch_metrics(context.integration,
                     http_plug: plug,
                     date_range: default_date_range()
                   )

          assert is_list(metrics)

          for metric <- metrics do
            assert metric.provider == :google_ads
            assert metric.metric_type == "advertising"
            assert is_binary(metric.metric_name)
            assert is_number(metric.value)
            assert %DateTime{} = metric.recorded_at
            assert is_map(metric.metadata)
            assert Map.has_key?(metric.metadata, :customer_id)
          end
        end
      end)
    end

    test "returns structured error for unauthorized request", context do
      if context[:skip], do: flunk("GOOGLE_ADS_TEST_CUSTOMER_ID not set in .env.test")

      capture_log(fn ->
        with_cassette "google_ads_unauthorized", cassette_opts("google_ads_unauthorized"), fn plug ->
          bad_token = %{context.integration | access_token: "invalid-token"}

          assert {:error, reason} =
                   GoogleAds.fetch_metrics(bad_token,
                     http_plug: plug,
                     date_range: default_date_range()
                   )

          assert reason in [:unauthorized, :insufficient_permissions, :customer_not_found]
        end
      end)
    end
  end
end
