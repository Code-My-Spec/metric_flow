defmodule MetricFlow.DataSync.DataProviders.FacebookAdsTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias MetricFlow.DataSync.DataProviders.FacebookAds
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
      provider: :facebook_ads,
      access_token: "EAABsbCS4IHABOC_valid_access_token",
      refresh_token: nil,
      expires_at: future_expires_at(),
      granted_scopes: ["ads_read", "ads_management"],
      provider_metadata: %{"ad_account_id" => "123456789"},
      user_id: 1
    )
  end

  defp expired_integration do
    struct!(Integration,
      id: 2,
      provider: :facebook_ads,
      access_token: "EAABsbCS4IHABOC_expired_token",
      refresh_token: nil,
      expires_at: past_expires_at(),
      granted_scopes: ["ads_read"],
      provider_metadata: %{"ad_account_id" => "123456789"},
      user_id: 1
    )
  end

  defp integration_without_ad_account_id do
    struct!(Integration,
      id: 3,
      provider: :facebook_ads,
      access_token: "EAABsbCS4IHABOC_valid_access_token",
      refresh_token: nil,
      expires_at: future_expires_at(),
      granted_scopes: ["ads_read"],
      provider_metadata: %{},
      user_id: 1
    )
  end

  # Used to verify act_ prefix is not doubled when provider_metadata already contains it
  defp integration_with_act_prefix do
    struct!(Integration,
      id: 4,
      provider: :facebook_ads,
      access_token: "EAABsbCS4IHABOC_valid_access_token",
      refresh_token: nil,
      expires_at: future_expires_at(),
      granted_scopes: ["ads_read", "ads_management"],
      provider_metadata: %{"ad_account_id" => "act_123456789"},
      user_id: 1
    )
  end

  # Two-row response with paging cursors but no paging.next link — single page only
  defp valid_api_response do
    Jason.encode!(%{
      "data" => [
        %{
          "campaign_name" => "Summer Campaign",
          "adset_name" => "Audience A",
          "date_start" => "2026-01-15",
          "impressions" => "10000",
          "clicks" => "500",
          "spend" => "250.75",
          "cpm" => "25.075",
          "cpc" => "0.5015",
          "ctr" => "5.0",
          "actions" => [
            %{"action_type" => "purchase", "value" => "10"},
            %{"action_type" => "link_click", "value" => "450"},
            %{"action_type" => "offsite_conversion", "value" => "5"}
          ]
        },
        %{
          "campaign_name" => "Winter Promo",
          "adset_name" => "Audience B",
          "date_start" => "2026-01-16",
          "impressions" => "8000",
          "clicks" => "320",
          "spend" => "180.50",
          "cpm" => "22.5625",
          "cpc" => "0.5641",
          "ctr" => "4.0",
          "actions" => [
            %{"action_type" => "purchase", "value" => "7"}
          ]
        }
      ],
      "paging" => %{
        "cursors" => %{
          "before" => "before_cursor_abc",
          "after" => "after_cursor_xyz"
        }
      }
    })
  end

  # Single-row response with no paging.next — used for most unit tests to keep assertions simple
  defp valid_api_response_no_paging_next do
    Jason.encode!(%{
      "data" => [
        %{
          "campaign_name" => "Summer Campaign",
          "adset_name" => "Audience A",
          "date_start" => "2026-01-15",
          "impressions" => "10000",
          "clicks" => "500",
          "spend" => "250.75",
          "cpm" => "25.075",
          "cpc" => "0.5015",
          "ctr" => "5.0",
          "actions" => [
            %{"action_type" => "purchase", "value" => "10"}
          ]
        }
      ],
      "paging" => %{
        "cursors" => %{
          "before" => "before_cursor_abc",
          "after" => "after_cursor_xyz"
        }
      }
    })
  end

  defp empty_api_response do
    Jason.encode!(%{"data" => []})
  end

  defp paginated_first_page_response do
    Jason.encode!(%{
      "data" => [
        %{
          "campaign_name" => "Page One Campaign",
          "adset_name" => "Adset One",
          "date_start" => "2026-01-15",
          "impressions" => "5000",
          "clicks" => "200",
          "spend" => "100.00",
          "cpm" => "20.0",
          "cpc" => "0.5",
          "ctr" => "4.0",
          "actions" => [%{"action_type" => "purchase", "value" => "5"}]
        }
      ],
      "paging" => %{
        "cursors" => %{
          "before" => "before_cursor",
          "after" => "cursor_for_next_page"
        },
        "next" => "https://graph.facebook.com/v18.0/act_123456789/insights?after=cursor_for_next_page"
      }
    })
  end

  defp paginated_second_page_response do
    Jason.encode!(%{
      "data" => [
        %{
          "campaign_name" => "Page Two Campaign",
          "adset_name" => "Adset Two",
          "date_start" => "2026-01-16",
          "impressions" => "3000",
          "clicks" => "120",
          "spend" => "60.00",
          "cpm" => "20.0",
          "cpc" => "0.5",
          "ctr" => "4.0",
          "actions" => [%{"action_type" => "purchase", "value" => "3"}]
        }
      ],
      "paging" => %{
        "cursors" => %{"before" => "before_cursor_2", "after" => "after_cursor_2"}
      }
    })
  end

  defp zero_impressions_response do
    Jason.encode!(%{
      "data" => [
        %{
          "campaign_name" => "Zero Traffic Campaign",
          "adset_name" => "Cold Adset",
          "date_start" => "2026-01-15",
          "impressions" => "0",
          "clicks" => "0",
          "spend" => "0.00",
          "cpm" => "0.0",
          "cpc" => "0.0",
          "ctr" => "0.0",
          "actions" => []
        }
      ],
      "paging" => %{"cursors" => %{"before" => "b", "after" => "a"}}
    })
  end

  defp null_dimensions_response do
    Jason.encode!(%{
      "data" => [
        %{
          "campaign_name" => nil,
          "adset_name" => nil,
          "date_start" => "2026-01-15",
          "impressions" => "5000",
          "clicks" => "200",
          "spend" => "100.00",
          "cpm" => "20.0",
          "cpc" => "0.5",
          "ctr" => "4.0",
          "actions" => [%{"action_type" => "purchase", "value" => "5"}]
        }
      ],
      "paging" => %{"cursors" => %{"before" => "b", "after" => "a"}}
    })
  end

  defp missing_actions_response do
    Jason.encode!(%{
      "data" => [
        %{
          "campaign_name" => "No Actions Campaign",
          "adset_name" => "Adset",
          "date_start" => "2026-01-15",
          "impressions" => "5000",
          "clicks" => "200",
          "spend" => "100.00",
          "cpm" => "20.0",
          "cpc" => "0.5",
          "ctr" => "4.0"
        }
      ],
      "paging" => %{"cursors" => %{"before" => "b", "after" => "a"}}
    })
  end

  defp empty_actions_response do
    Jason.encode!(%{
      "data" => [
        %{
          "campaign_name" => "Empty Actions Campaign",
          "adset_name" => "Adset",
          "date_start" => "2026-01-15",
          "impressions" => "5000",
          "clicks" => "200",
          "spend" => "100.00",
          "cpm" => "20.0",
          "cpc" => "0.5",
          "ctr" => "4.0",
          "actions" => []
        }
      ],
      "paging" => %{"cursors" => %{"before" => "b", "after" => "a"}}
    })
  end

  defp multiple_action_types_response do
    Jason.encode!(%{
      "data" => [
        %{
          "campaign_name" => "Multi Action Campaign",
          "adset_name" => "Adset",
          "date_start" => "2026-01-15",
          "impressions" => "10000",
          "clicks" => "500",
          "spend" => "200.00",
          "cpm" => "20.0",
          "cpc" => "0.4",
          "ctr" => "5.0",
          "actions" => [
            %{"action_type" => "purchase", "value" => "8"},
            %{"action_type" => "link_click", "value" => "450"},
            %{"action_type" => "video_view", "value" => "1200"},
            %{"action_type" => "offsite_conversion", "value" => "6"},
            %{"action_type" => "post_engagement", "value" => "300"}
          ]
        }
      ],
      "paging" => %{"cursors" => %{"before" => "b", "after" => "a"}}
    })
  end

  defp oauth_error_response do
    Jason.encode!(%{
      "error" => %{
        "message" => "Invalid OAuth access token",
        "type" => "OAuthException",
        "code" => 190,
        "error_subcode" => 458
      }
    })
  end

  defp insufficient_permissions_error_response do
    Jason.encode!(%{
      "error" => %{
        "message" => "Permissions error",
        "type" => "GraphMethodException",
        "code" => 200
      }
    })
  end

  defp bad_request_error_response do
    Jason.encode!(%{
      "error" => %{
        "message" => "Invalid parameter",
        "type" => "GraphInvalidParameterException",
        "code" => 100,
        "error_user_msg" => "Invalid ad account ID"
      }
    })
  end

  defp rate_limit_error_response do
    Jason.encode!(%{
      "error" => %{
        "message" => "User request limit reached",
        "type" => "OAuthException",
        "code" => 17
      }
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
      send(test_pid, {:request, conn})

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, valid_api_response_no_paging_next())
    end
  end

  # ---------------------------------------------------------------------------
  # fetch_metrics/2
  # ---------------------------------------------------------------------------

  describe "fetch_metrics/2" do
    test "returns ok tuple with list of metrics for valid integration and options" do
      plug = build_stub_plug(200, valid_api_response_no_paging_next())

      assert {:ok, metrics} =
               FacebookAds.fetch_metrics(valid_integration(), http_plug: plug)

      assert is_list(metrics)
      assert metrics != []
    end

    test "extracts access_token from integration struct" do
      test_pid = self()
      plug = capture_request_plug(test_pid)

      capture_log(fn ->
        FacebookAds.fetch_metrics(valid_integration(), http_plug: plug)
      end)

      assert_receive {:request, conn}
      query_string = conn.query_string
      assert String.contains?(query_string, "access_token=EAABsbCS4IHABOC_valid_access_token")
    end

    test "includes access_token as query parameter in request URL" do
      test_pid = self()
      plug = capture_request_plug(test_pid)

      capture_log(fn ->
        FacebookAds.fetch_metrics(valid_integration(), http_plug: plug)
      end)

      assert_receive {:request, conn}
      assert String.contains?(conn.query_string, "access_token=")
    end

    test "builds correct Facebook Marketing API URL with ad_account_id" do
      test_pid = self()
      plug = capture_request_plug(test_pid)

      capture_log(fn ->
        FacebookAds.fetch_metrics(
          valid_integration(),
          ad_account_id: "987654321",
          http_plug: plug
        )
      end)

      assert_receive {:request, conn}
      assert String.contains?(conn.request_path, "act_987654321")
      assert String.contains?(conn.request_path, "insights")
    end

    test "prepends act_ to ad_account_id when not present" do
      test_pid = self()
      plug = capture_request_plug(test_pid)

      capture_log(fn ->
        FacebookAds.fetch_metrics(
          valid_integration(),
          ad_account_id: "123456789",
          http_plug: plug
        )
      end)

      assert_receive {:request, conn}
      assert String.contains?(conn.request_path, "act_123456789")
    end

    test "does not double-prepend act_ when already present" do
      test_pid = self()
      plug = capture_request_plug(test_pid)

      capture_log(fn ->
        FacebookAds.fetch_metrics(integration_with_act_prefix(), http_plug: plug)
      end)

      assert_receive {:request, conn}
      assert String.contains?(conn.request_path, "act_123456789")
      refute String.contains?(conn.request_path, "act_act_123456789")
    end

    test "sets ad_account_id from options when provided" do
      test_pid = self()
      plug = capture_request_plug(test_pid)

      capture_log(fn ->
        FacebookAds.fetch_metrics(
          valid_integration(),
          ad_account_id: "options_account_99",
          http_plug: plug
        )
      end)

      assert_receive {:request, conn}
      assert String.contains?(conn.request_path, "options_account_99")
    end

    test "sets ad_account_id from provider_metadata when not in options" do
      test_pid = self()
      plug = capture_request_plug(test_pid)

      capture_log(fn ->
        FacebookAds.fetch_metrics(valid_integration(), http_plug: plug)
      end)

      assert_receive {:request, conn}
      assert String.contains?(conn.request_path, "123456789")
    end

    test "adds fields parameter with impressions, clicks, spend, conversions to request" do
      test_pid = self()
      plug = capture_request_plug(test_pid)

      capture_log(fn ->
        FacebookAds.fetch_metrics(valid_integration(), http_plug: plug)
      end)

      assert_receive {:request, conn}
      fields = conn.query_string
      assert String.contains?(fields, "impressions")
      assert String.contains?(fields, "clicks")
      assert String.contains?(fields, "spend")
    end

    test "adds fields parameter with cpm, cpc, ctr, actions to request" do
      test_pid = self()
      plug = capture_request_plug(test_pid)

      capture_log(fn ->
        FacebookAds.fetch_metrics(valid_integration(), http_plug: plug)
      end)

      assert_receive {:request, conn}
      fields = conn.query_string
      assert String.contains?(fields, "cpm")
      assert String.contains?(fields, "cpc")
      assert String.contains?(fields, "ctr")
      assert String.contains?(fields, "actions")
    end

    test "includes campaign_name and date_start dimensions by default" do
      test_pid = self()
      plug = capture_request_plug(test_pid)

      capture_log(fn ->
        FacebookAds.fetch_metrics(valid_integration(), http_plug: plug)
      end)

      assert_receive {:request, conn}
      assert String.contains?(conn.query_string, "campaign_name")
      assert String.contains?(conn.query_string, "date_start")
    end

    test "includes adset_name dimension when breakdown is :adset" do
      test_pid = self()
      plug = capture_request_plug(test_pid)

      capture_log(fn ->
        FacebookAds.fetch_metrics(valid_integration(), breakdown: :adset, http_plug: plug)
      end)

      assert_receive {:request, conn}
      assert String.contains?(conn.query_string, "adset_name")
    end

    test "sets time_range parameter with since and until dates" do
      test_pid = self()
      plug = capture_request_plug(test_pid)

      since = ~D[2026-01-01]
      until = ~D[2026-01-31]

      capture_log(fn ->
        FacebookAds.fetch_metrics(
          valid_integration(),
          date_range: {since, until},
          http_plug: plug
        )
      end)

      assert_receive {:request, conn}
      assert String.contains?(conn.query_string, "time_range")
    end

    test "defaults to last 30 days when date_range not provided" do
      test_pid = self()
      plug = capture_request_plug(test_pid)

      capture_log(fn ->
        FacebookAds.fetch_metrics(valid_integration(), http_plug: plug)
      end)

      assert_receive {:request, conn}
      today = Date.utc_today()
      expected_start = Date.add(today, -30)

      assert String.contains?(conn.query_string, Date.to_iso8601(today))
      assert String.contains?(conn.query_string, Date.to_iso8601(expected_start))
    end

    test "formats dates as YYYY-MM-DD in time_range parameter" do
      test_pid = self()
      plug = capture_request_plug(test_pid)

      since = ~D[2026-01-01]
      until = ~D[2026-01-31]

      capture_log(fn ->
        FacebookAds.fetch_metrics(
          valid_integration(),
          date_range: {since, until},
          http_plug: plug
        )
      end)

      assert_receive {:request, conn}
      assert String.contains?(conn.query_string, "2026-01-01")
      assert String.contains?(conn.query_string, "2026-01-31")
    end

    test "sets level parameter to campaign by default" do
      test_pid = self()
      plug = capture_request_plug(test_pid)

      capture_log(fn ->
        FacebookAds.fetch_metrics(valid_integration(), http_plug: plug)
      end)

      assert_receive {:request, conn}
      assert String.contains?(conn.query_string, "level=campaign")
    end

    test "sets level parameter to adset when breakdown is :adset" do
      test_pid = self()
      plug = capture_request_plug(test_pid)

      capture_log(fn ->
        FacebookAds.fetch_metrics(valid_integration(), breakdown: :adset, http_plug: plug)
      end)

      assert_receive {:request, conn}
      assert String.contains?(conn.query_string, "level=adset")
    end

    test "transforms Facebook API response data to unified metric format" do
      plug = build_stub_plug(200, valid_api_response_no_paging_next())

      assert {:ok, metrics} = FacebookAds.fetch_metrics(valid_integration(), http_plug: plug)

      assert is_list(metrics)
      assert Enum.all?(metrics, &is_map/1)

      for metric <- metrics do
        assert Map.has_key?(metric, :metric_type)
        assert Map.has_key?(metric, :metric_name)
        assert Map.has_key?(metric, :value)
        assert Map.has_key?(metric, :recorded_at)
        assert Map.has_key?(metric, :metadata)
        assert Map.has_key?(metric, :provider)
      end
    end

    test "sets provider to :facebook_ads for all metrics" do
      plug = build_stub_plug(200, valid_api_response_no_paging_next())

      assert {:ok, metrics} = FacebookAds.fetch_metrics(valid_integration(), http_plug: plug)

      for metric <- metrics do
        assert metric.provider == :facebook_ads
      end
    end

    test "extracts recorded_at from date_start field value" do
      plug = build_stub_plug(200, valid_api_response_no_paging_next())

      assert {:ok, metrics} = FacebookAds.fetch_metrics(valid_integration(), http_plug: plug)

      assert Enum.any?(metrics, fn metric ->
               %DateTime{year: 2026, month: 1, day: 15} = metric.recorded_at
               true
             end)
    end

    test "converts spend to dollars with appropriate precision" do
      plug = build_stub_plug(200, valid_api_response_no_paging_next())

      assert {:ok, metrics} = FacebookAds.fetch_metrics(valid_integration(), http_plug: plug)

      spend_metric = Enum.find(metrics, fn m -> m.metric_name == "spend" end)
      assert spend_metric != nil
      assert is_float(spend_metric.value)
      assert spend_metric.value == 250.75
    end

    test "extracts cpm as cost per thousand impressions" do
      plug = build_stub_plug(200, valid_api_response_no_paging_next())

      assert {:ok, metrics} = FacebookAds.fetch_metrics(valid_integration(), http_plug: plug)

      cpm_metric = Enum.find(metrics, fn m -> m.metric_name == "cpm" end)
      assert cpm_metric != nil
      assert is_float(cpm_metric.value)
    end

    test "extracts cpc as cost per click" do
      plug = build_stub_plug(200, valid_api_response_no_paging_next())

      assert {:ok, metrics} = FacebookAds.fetch_metrics(valid_integration(), http_plug: plug)

      cpc_metric = Enum.find(metrics, fn m -> m.metric_name == "cpc" end)
      assert cpc_metric != nil
      assert is_float(cpc_metric.value)
    end

    test "extracts ctr as percentage value" do
      plug = build_stub_plug(200, valid_api_response_no_paging_next())

      assert {:ok, metrics} = FacebookAds.fetch_metrics(valid_integration(), http_plug: plug)

      ctr_metric = Enum.find(metrics, fn m -> m.metric_name == "ctr" end)
      assert ctr_metric != nil
      assert is_float(ctr_metric.value)
      assert ctr_metric.value == 5.0
    end

    test "calculates conversion_rate from conversions and impressions when not provided" do
      plug = build_stub_plug(200, valid_api_response_no_paging_next())

      assert {:ok, metrics} = FacebookAds.fetch_metrics(valid_integration(), http_plug: plug)

      conversion_rate_metric = Enum.find(metrics, fn m -> m.metric_name == "conversion_rate" end)
      assert conversion_rate_metric != nil
      assert is_float(conversion_rate_metric.value)
    end

    test "extracts conversion count from actions array by action_type" do
      plug = build_stub_plug(200, valid_api_response_no_paging_next())

      assert {:ok, metrics} = FacebookAds.fetch_metrics(valid_integration(), http_plug: plug)

      conversions_metric = Enum.find(metrics, fn m -> m.metric_name == "conversions" end)
      assert conversions_metric != nil
      assert conversions_metric.value == 10
    end

    test "handles multiple action types in actions array" do
      plug = build_stub_plug(200, multiple_action_types_response())

      assert {:ok, metrics} = FacebookAds.fetch_metrics(valid_integration(), http_plug: plug)

      conversions_metric = Enum.find(metrics, fn m -> m.metric_name == "conversions" end)
      assert conversions_metric != nil
      assert conversions_metric.value == 14
    end

    test "filters actions to purchase or offsite_conversion types" do
      plug = build_stub_plug(200, multiple_action_types_response())

      assert {:ok, metrics} = FacebookAds.fetch_metrics(valid_integration(), http_plug: plug)

      conversions_metric = Enum.find(metrics, fn m -> m.metric_name == "conversions" end)
      assert conversions_metric != nil
      assert conversions_metric.value == 14
    end

    test "converts dimension values to metadata map with atom keys" do
      plug = build_stub_plug(200, valid_api_response_no_paging_next())

      assert {:ok, metrics} = FacebookAds.fetch_metrics(valid_integration(), http_plug: plug)

      for metric <- metrics do
        assert is_map(metric.metadata)
        assert Map.keys(metric.metadata) |> Enum.all?(&is_atom/1)
      end
    end

    test "includes campaign_name in metadata" do
      plug = build_stub_plug(200, valid_api_response_no_paging_next())

      assert {:ok, metrics} = FacebookAds.fetch_metrics(valid_integration(), http_plug: plug)

      first_metric = List.first(metrics)
      assert Map.has_key?(first_metric.metadata, :campaign_name)
      assert first_metric.metadata.campaign_name == "Summer Campaign"
    end

    test "includes adset_name in metadata when present" do
      plug = build_stub_plug(200, valid_api_response_no_paging_next())

      assert {:ok, metrics} = FacebookAds.fetch_metrics(valid_integration(), http_plug: plug)

      first_metric = List.first(metrics)
      assert Map.has_key?(first_metric.metadata, :adset_name)
      assert first_metric.metadata.adset_name == "Audience A"
    end

    test "includes ad_account_id in metadata" do
      plug = build_stub_plug(200, valid_api_response_no_paging_next())

      assert {:ok, metrics} = FacebookAds.fetch_metrics(valid_integration(), http_plug: plug)

      for metric <- metrics do
        assert Map.has_key?(metric.metadata, :ad_account_id)
        assert metric.metadata.ad_account_id != nil
      end
    end

    test "converts metric values to appropriate numeric types (integer or float)" do
      plug = build_stub_plug(200, valid_api_response_no_paging_next())

      assert {:ok, metrics} = FacebookAds.fetch_metrics(valid_integration(), http_plug: plug)

      for metric <- metrics do
        assert is_integer(metric.value) or is_float(metric.value)
      end
    end

    test "handles spend as float" do
      plug = build_stub_plug(200, valid_api_response_no_paging_next())

      assert {:ok, metrics} = FacebookAds.fetch_metrics(valid_integration(), http_plug: plug)

      spend_metric = Enum.find(metrics, fn m -> m.metric_name == "spend" end)
      assert spend_metric != nil
      assert is_float(spend_metric.value)
    end

    test "returns error :missing_ad_account_id when ad_account_id not in options or metadata" do
      assert {:error, :missing_ad_account_id} =
               FacebookAds.fetch_metrics(integration_without_ad_account_id(), [])
    end

    test "returns error :unauthorized when token is invalid or expired" do
      assert {:error, :unauthorized} =
               FacebookAds.fetch_metrics(expired_integration(), [])
    end

    test "returns error :insufficient_permissions when token lacks ads_read scope" do
      plug = build_stub_plug(403, insufficient_permissions_error_response())

      assert {:error, :insufficient_permissions} =
               FacebookAds.fetch_metrics(valid_integration(), http_plug: plug)
    end

    test "returns error :invalid_token when API returns OAuth error code 190" do
      plug = build_stub_plug(400, oauth_error_response())

      assert {:error, :invalid_token} =
               FacebookAds.fetch_metrics(valid_integration(), http_plug: plug)
    end

    test "returns error with Facebook API details when request is invalid" do
      plug = build_stub_plug(400, bad_request_error_response())

      assert {:error, _reason} =
               FacebookAds.fetch_metrics(valid_integration(), http_plug: plug)
    end

    test "handles network errors gracefully with error tuple" do
      error_plug = fn _conn ->
        raise %Req.TransportError{reason: :econnrefused}
      end

      assert {:error, {:network_error, _reason}} =
               FacebookAds.fetch_metrics(valid_integration(), http_plug: error_plug)
    end

    test "handles malformed JSON response with error tuple" do
      malformed_plug = fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("text/plain")
        |> Plug.Conn.send_resp(200, "not valid json {{{")
      end

      assert {:error, :malformed_response} =
               FacebookAds.fetch_metrics(valid_integration(), http_plug: malformed_plug)
    end

    test "handles empty data array with empty list" do
      plug = build_stub_plug(200, empty_api_response())

      assert {:ok, []} = FacebookAds.fetch_metrics(valid_integration(), http_plug: plug)
    end

    test "handles API rate limiting with error :rate_limited" do
      plug = build_stub_plug(429, rate_limit_error_response())

      assert {:error, :rate_limited} =
               FacebookAds.fetch_metrics(valid_integration(), http_plug: plug)
    end

    test "respects cursor-based pagination with after parameter" do
      test_pid = self()
      page_count = :counters.new(1, [:atomics])

      multi_page_plug = fn conn ->
        count = :counters.get(page_count, 1) + 1
        :counters.put(page_count, 1, count)
        send(test_pid, {:page_request, count, conn})

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
               FacebookAds.fetch_metrics(valid_integration(), http_plug: multi_page_plug)

      assert_receive {:page_request, 2, second_conn}
      assert String.contains?(second_conn.query_string, "after=cursor_for_next_page")
    end

    test "fetches multiple pages when paging.next present in response" do
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

      assert {:ok, metrics} =
               FacebookAds.fetch_metrics(valid_integration(), http_plug: multi_page_plug)

      assert_receive {:page_request, 1}
      assert_receive {:page_request, 2}
      assert is_list(metrics)
    end

    test "appends results from all pages to single metrics list" do
      page_count = :counters.new(1, [:atomics])

      multi_page_plug = fn conn ->
        count = :counters.get(page_count, 1) + 1
        :counters.put(page_count, 1, count)

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

      assert {:ok, metrics} =
               FacebookAds.fetch_metrics(valid_integration(), http_plug: multi_page_plug)

      campaign_names =
        metrics
        |> Enum.map(fn m -> m.metadata[:campaign_name] end)
        |> Enum.uniq()

      assert "Page One Campaign" in campaign_names
      assert "Page Two Campaign" in campaign_names
    end

    test "stops pagination when paging.next is null or absent" do
      # valid_api_response has two rows but no paging.next key — proves only one page is fetched
      plug = build_stub_plug(200, valid_api_response())

      assert {:ok, metrics} = FacebookAds.fetch_metrics(valid_integration(), http_plug: plug)

      campaign_names =
        metrics
        |> Enum.map(fn m -> m.metadata[:campaign_name] end)
        |> Enum.uniq()

      assert "Summer Campaign" in campaign_names
      assert "Winter Promo" in campaign_names
    end

    test "handles campaigns with zero impressions or clicks" do
      plug = build_stub_plug(200, zero_impressions_response())

      assert {:ok, metrics} = FacebookAds.fetch_metrics(valid_integration(), http_plug: plug)

      impressions_metric = Enum.find(metrics, fn m -> m.metric_name == "impressions" end)
      assert impressions_metric != nil
      assert impressions_metric.value == 0
    end

    test "handles null or missing dimension values gracefully" do
      plug = build_stub_plug(200, null_dimensions_response())

      assert {:ok, metrics} = FacebookAds.fetch_metrics(valid_integration(), http_plug: plug)

      assert is_list(metrics)
      assert metrics != []
    end

    test "handles missing actions array by setting conversions to zero" do
      plug = build_stub_plug(200, missing_actions_response())

      assert {:ok, metrics} = FacebookAds.fetch_metrics(valid_integration(), http_plug: plug)

      conversions_metric = Enum.find(metrics, fn m -> m.metric_name == "conversions" end)
      assert conversions_metric != nil
      assert conversions_metric.value == 0
    end

    test "handles empty actions array by setting conversions to zero" do
      plug = build_stub_plug(200, empty_actions_response())

      assert {:ok, metrics} = FacebookAds.fetch_metrics(valid_integration(), http_plug: plug)

      conversions_metric = Enum.find(metrics, fn m -> m.metric_name == "conversions" end)
      assert conversions_metric != nil
      assert conversions_metric.value == 0
    end

    test "handles date_start field as ISO 8601 date string" do
      plug = build_stub_plug(200, valid_api_response_no_paging_next())

      assert {:ok, metrics} = FacebookAds.fetch_metrics(valid_integration(), http_plug: plug)

      for metric <- metrics do
        assert %DateTime{} = metric.recorded_at
      end
    end
  end

  # ---------------------------------------------------------------------------
  # provider/0
  # ---------------------------------------------------------------------------

  describe "provider/0" do
    test "returns :facebook_ads atom" do
      assert FacebookAds.provider() == :facebook_ads
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

      assert FacebookAds.provider() in valid_providers
    end
  end

  # ---------------------------------------------------------------------------
  # required_scopes/0
  # ---------------------------------------------------------------------------

  describe "required_scopes/0" do
    test "returns list with ads_read scope" do
      scopes = FacebookAds.required_scopes()

      assert "ads_read" in scopes
    end

    test "returns list with ads_management scope" do
      scopes = FacebookAds.required_scopes()

      assert "ads_management" in scopes
    end

    test "returned scopes are strings not atoms" do
      scopes = FacebookAds.required_scopes()

      assert Enum.all?(scopes, &is_binary/1)
    end

    test "list contains exactly two scopes" do
      scopes = FacebookAds.required_scopes()

      assert length(scopes) == 2
    end

    test "scopes match Facebook Marketing API requirements" do
      scopes = FacebookAds.required_scopes()

      assert "ads_read" in scopes
      assert "ads_management" in scopes
    end

    test "ads_read scope is included for read-only access" do
      scopes = FacebookAds.required_scopes()

      assert "ads_read" in scopes
    end

    test "ads_management scope is included for full account access" do
      scopes = FacebookAds.required_scopes()

      assert "ads_management" in scopes
    end
  end
end
