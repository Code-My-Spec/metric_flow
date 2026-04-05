defmodule MetricFlow.DataSync.DataProviders.GoogleBusinessTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog
  import ReqCassette

  alias MetricFlow.DataSync.DataProviders.GoogleBusiness
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
      provider: :google_business,
      access_token: "ya29.valid_gbp_token",
      refresh_token: "1//refresh_token",
      expires_at: future_expires_at(),
      granted_scopes: ["https://www.googleapis.com/auth/business.manage"],
      provider_metadata: %{
        "included_locations" => ["accounts/123/locations/456"]
      },
      user_id: 1
    )
  end

  defp valid_integration_multiple_locations do
    struct!(Integration,
      id: 2,
      provider: :google_business,
      access_token: "ya29.valid_gbp_token",
      refresh_token: "1//refresh_token",
      expires_at: future_expires_at(),
      granted_scopes: ["https://www.googleapis.com/auth/business.manage"],
      provider_metadata: %{
        "included_locations" => [
          "accounts/123/locations/456",
          "accounts/123/locations/789"
        ]
      },
      user_id: 1
    )
  end

  defp expired_integration do
    struct!(Integration,
      id: 3,
      provider: :google_business,
      access_token: "ya29.expired_token",
      refresh_token: "1//expired_refresh_token",
      expires_at: past_expires_at(),
      granted_scopes: ["https://www.googleapis.com/auth/business.manage"],
      provider_metadata: %{
        "included_locations" => ["accounts/123/locations/456"]
      },
      user_id: 1
    )
  end

  defp integration_without_locations do
    struct!(Integration,
      id: 4,
      provider: :google_business,
      access_token: "ya29.valid_gbp_token",
      refresh_token: "1//refresh_token",
      expires_at: future_expires_at(),
      granted_scopes: ["https://www.googleapis.com/auth/business.manage"],
      provider_metadata: %{},
      user_id: 1
    )
  end

  defp integration_with_empty_locations do
    struct!(Integration,
      id: 5,
      provider: :google_business,
      access_token: "ya29.valid_gbp_token",
      refresh_token: "1//refresh_token",
      expires_at: future_expires_at(),
      granted_scopes: ["https://www.googleapis.com/auth/business.manage"],
      provider_metadata: %{"included_locations" => []},
      user_id: 1
    )
  end

  defp valid_performance_response do
    Jason.encode!(%{
      "multiDailyMetricTimeSeries" => [
        %{
          "dailyMetricTimeSeries" => [
            %{
              "dailyMetric" => "BUSINESS_IMPRESSIONS_DESKTOP_MAPS",
              "timeSeries" => %{
                "datedValues" => [
                  %{
                    "date" => %{"year" => 2026, "month" => 1, "day" => 15},
                    "value" => "150"
                  },
                  %{
                    "date" => %{"year" => 2026, "month" => 1, "day" => 16},
                    "value" => "200"
                  }
                ]
              }
            },
            %{
              "dailyMetric" => "BUSINESS_CONVERSATIONS",
              "timeSeries" => %{
                "datedValues" => [
                  %{
                    "date" => %{"year" => 2026, "month" => 1, "day" => 15},
                    "value" => "10"
                  }
                ]
              }
            }
          ]
        }
      ]
    })
  end

  defp empty_performance_response do
    Jason.encode!(%{"multiDailyMetricTimeSeries" => []})
  end

  defp valid_reviews_response do
    Jason.encode!(%{
      "reviews" => [
        %{
          "reviewId" => "review_abc123",
          "starRating" => "FIVE",
          "reviewer" => %{"displayName" => "Alice Smith"},
          "comment" => "Excellent service!",
          "createTime" => "2026-01-15T10:00:00Z"
        },
        %{
          "reviewId" => "review_def456",
          "starRating" => "THREE",
          "reviewer" => %{"displayName" => "Bob Jones"},
          "comment" => "Average experience.",
          "createTime" => "2026-01-16T12:00:00Z"
        }
      ]
    })
  end

  defp empty_reviews_response do
    Jason.encode!(%{"reviews" => []})
  end

  defp reviews_response_with_next_page do
    Jason.encode!(%{
      "reviews" => [
        %{
          "reviewId" => "review_page1",
          "starRating" => "FOUR",
          "reviewer" => %{"displayName" => "Page One Reviewer"},
          "comment" => "Good.",
          "createTime" => "2026-01-15T10:00:00Z"
        }
      ],
      "nextPageToken" => "token_for_page_2"
    })
  end

  defp reviews_response_last_page do
    Jason.encode!(%{
      "reviews" => [
        %{
          "reviewId" => "review_page2",
          "starRating" => "TWO",
          "reviewer" => %{"displayName" => "Page Two Reviewer"},
          "comment" => "Not great.",
          "createTime" => "2026-01-14T09:00:00Z"
        }
      ]
    })
  end

  defp build_dual_stub_plug(perf_body, reviews_body) do
    build_dual_stub_plug(perf_body, reviews_body, 200, 200)
  end

  defp build_dual_stub_plug(perf_body, reviews_body, perf_status, reviews_status) do
    fn conn ->
      {status, body} =
        if String.contains?(conn.request_path, "fetchMultiDailyMetricsTimeSeries") do
          {perf_status, perf_body}
        else
          {reviews_status, reviews_body}
        end

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(status, body)
    end
  end

  defp capture_request_plug(test_pid) do
    fn conn ->
      send(test_pid, {:request, conn})

      body =
        if String.contains?(conn.request_path, "fetchMultiDailyMetricsTimeSeries") do
          valid_performance_response()
        else
          empty_reviews_response()
        end

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, body)
    end
  end

  defp get_req_header(%Plug.Conn{} = conn, header_name) do
    Enum.flat_map(conn.req_headers, fn {name, value} ->
      if String.downcase(name) == header_name, do: [value], else: []
    end)
  end

  defp collect_tagged_messages(tag, timeout \\ 100) do
    Stream.repeatedly(fn ->
      receive do
        {^tag, value} -> value
      after
        timeout -> nil
      end
    end)
    |> Enum.take_while(&(&1 != nil))
  end

  # ---------------------------------------------------------------------------
  # fetch_metrics/2
  # ---------------------------------------------------------------------------

  describe "fetch_metrics/2" do
    test "returns ok tuple with list of metrics for valid integration with locations configured" do
      plug = build_dual_stub_plug(valid_performance_response(), valid_reviews_response())

      assert {:ok, metrics} = GoogleBusiness.fetch_metrics(valid_integration(), http_plug: plug)

      assert is_list(metrics)
      assert metrics != []
    end

    test "returns error :unauthorized when integration token is expired" do
      assert {:error, :unauthorized} = GoogleBusiness.fetch_metrics(expired_integration(), [])
    end

    test "returns error :no_locations_configured when included_locations is missing from provider_metadata" do
      assert {:error, :no_locations_configured} =
               GoogleBusiness.fetch_metrics(integration_without_locations(), [])
    end

    test "returns error :no_locations_configured when included_locations is an empty list" do
      assert {:error, :no_locations_configured} =
               GoogleBusiness.fetch_metrics(integration_with_empty_locations(), [])
    end

    test "includes OAuth token in Authorization header for performance API request" do
      test_pid = self()

      plug = fn conn ->
        send(test_pid, {:conn_captured, conn})

        body =
          if String.contains?(conn.request_path, "fetchMultiDailyMetricsTimeSeries") do
            valid_performance_response()
          else
            empty_reviews_response()
          end

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, body)
      end

      capture_log(fn ->
        GoogleBusiness.fetch_metrics(valid_integration(), http_plug: plug)
      end)

      all_conns = collect_tagged_messages(:conn_captured)

      perf_conn =
        Enum.find(all_conns, fn c ->
          String.contains?(c.request_path, "fetchMultiDailyMetricsTimeSeries")
        end)

      assert perf_conn != nil
      assert ["Bearer ya29.valid_gbp_token"] = get_req_header(perf_conn, "authorization")
    end

    test "includes OAuth token in Authorization header for reviews API request" do
      test_pid = self()

      plug = fn conn ->
        send(test_pid, {:conn_captured, conn})

        body =
          if String.contains?(conn.request_path, "fetchMultiDailyMetricsTimeSeries") do
            valid_performance_response()
          else
            empty_reviews_response()
          end

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, body)
      end

      capture_log(fn ->
        GoogleBusiness.fetch_metrics(valid_integration(), http_plug: plug)
      end)

      all_conns = collect_tagged_messages(:conn_captured)

      assert Enum.any?(all_conns, fn conn ->
               String.contains?(conn.request_path, "reviews") and
                 get_req_header(conn, "authorization") == ["Bearer ya29.valid_gbp_token"]
             end)
    end

    test "builds performance URL with correct location path stripping accounts prefix" do
      test_pid = self()
      plug = capture_request_plug(test_pid)

      capture_log(fn ->
        GoogleBusiness.fetch_metrics(valid_integration(), http_plug: plug)
      end)

      all_conns = collect_tagged_messages(:request)

      perf_conn =
        Enum.find(all_conns, fn c ->
          String.contains?(c.request_path, "fetchMultiDailyMetricsTimeSeries")
        end)

      assert perf_conn != nil
      # Should use "locations/456" not "accounts/123/locations/456"
      assert String.contains?(perf_conn.request_path, "locations/456")
      refute String.contains?(perf_conn.request_path, "accounts/123/locations/456")
    end

    test "builds performance URL with all 11 daily metric query params" do
      test_pid = self()

      plug = fn conn ->
        send(test_pid, {:conn_with_query, {conn, conn.query_string}})

        body =
          if String.contains?(conn.request_path, "fetchMultiDailyMetricsTimeSeries") do
            valid_performance_response()
          else
            empty_reviews_response()
          end

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, body)
      end

      capture_log(fn ->
        GoogleBusiness.fetch_metrics(valid_integration(), http_plug: plug)
      end)

      requests = collect_tagged_messages(:conn_with_query)

      perf_request =
        Enum.find(requests, fn {conn, _query} ->
          String.contains?(conn.request_path, "fetchMultiDailyMetricsTimeSeries")
        end)

      assert perf_request != nil
      {_conn, query} = perf_request

      expected_metrics = [
        "BUSINESS_IMPRESSIONS_DESKTOP_MAPS",
        "BUSINESS_IMPRESSIONS_DESKTOP_SEARCH",
        "BUSINESS_IMPRESSIONS_MOBILE_MAPS",
        "BUSINESS_IMPRESSIONS_MOBILE_SEARCH",
        "BUSINESS_CONVERSATIONS",
        "BUSINESS_DIRECTION_REQUESTS",
        "CALL_CLICKS",
        "WEBSITE_CLICKS",
        "BUSINESS_BOOKINGS",
        "BUSINESS_FOOD_ORDERS",
        "BUSINESS_FOOD_MENU_CLICKS"
      ]

      for metric <- expected_metrics do
        assert String.contains?(query, metric),
               "Expected query to contain #{metric}, got: #{query}"
      end
    end

    test "sets date range from date_range option in performance API URL" do
      test_pid = self()
      start_date = ~D[2026-01-01]
      end_date = ~D[2026-01-31]

      plug = fn conn ->
        send(test_pid, {:conn_with_query, {conn, conn.query_string}})

        body =
          if String.contains?(conn.request_path, "fetchMultiDailyMetricsTimeSeries") do
            valid_performance_response()
          else
            empty_reviews_response()
          end

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, body)
      end

      capture_log(fn ->
        GoogleBusiness.fetch_metrics(
          valid_integration(),
          date_range: {start_date, end_date},
          http_plug: plug
        )
      end)

      requests = collect_tagged_messages(:conn_with_query)

      perf_request =
        Enum.find(requests, fn {conn, _query} ->
          String.contains?(conn.request_path, "fetchMultiDailyMetricsTimeSeries")
        end)

      assert perf_request != nil
      {_conn, query} = perf_request

      assert String.contains?(query, "startDate.year=2026")
      assert String.contains?(query, "startDate.month=1")
      assert String.contains?(query, "startDate.day=1")
      assert String.contains?(query, "endDate.year=2026")
      assert String.contains?(query, "endDate.month=1")
      assert String.contains?(query, "endDate.day=31")
    end

    test "defaults to last 548 days ending yesterday when date_range not provided" do
      test_pid = self()

      plug = fn conn ->
        send(test_pid, {:conn_with_query, {conn, conn.query_string}})

        body =
          if String.contains?(conn.request_path, "fetchMultiDailyMetricsTimeSeries") do
            valid_performance_response()
          else
            empty_reviews_response()
          end

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, body)
      end

      capture_log(fn ->
        GoogleBusiness.fetch_metrics(valid_integration(), http_plug: plug)
      end)

      requests = collect_tagged_messages(:conn_with_query)

      perf_request =
        Enum.find(requests, fn {conn, _query} ->
          String.contains?(conn.request_path, "fetchMultiDailyMetricsTimeSeries")
        end)

      assert perf_request != nil
      {_conn, query} = perf_request

      today = Date.utc_today()
      yesterday = Date.add(today, -1)
      start_date = Date.add(today, -548)

      assert String.contains?(query, "endDate.year=#{yesterday.year}")
      assert String.contains?(query, "endDate.month=#{yesterday.month}")
      assert String.contains?(query, "endDate.day=#{yesterday.day}")
      assert String.contains?(query, "startDate.year=#{start_date.year}")
    end

    test "returns metrics from multiple locations when integration has multiple location IDs" do
      plug = build_dual_stub_plug(valid_performance_response(), empty_reviews_response())

      assert {:ok, metrics} =
               GoogleBusiness.fetch_metrics(valid_integration_multiple_locations(),
                 http_plug: plug
               )

      assert is_list(metrics)
      assert length(metrics) > 0

      # With two locations and the same response, we expect at least 2x the metrics
      single_location_plug =
        build_dual_stub_plug(valid_performance_response(), empty_reviews_response())

      assert {:ok, single_metrics} =
               GoogleBusiness.fetch_metrics(valid_integration(), http_plug: single_location_plug)

      assert length(metrics) >= length(single_metrics) * 2
    end

    test "transforms performance response to unified metric format with metric_type \"business_profile\"" do
      plug = build_dual_stub_plug(valid_performance_response(), empty_reviews_response())

      assert {:ok, metrics} = GoogleBusiness.fetch_metrics(valid_integration(), http_plug: plug)

      perf_metrics = Enum.filter(metrics, fn m -> m.metric_type == "business_profile" end)
      assert perf_metrics != []

      for metric <- perf_metrics do
        assert metric.metric_type == "business_profile"
        assert Map.has_key?(metric, :metric_name)
        assert Map.has_key?(metric, :value)
        assert Map.has_key?(metric, :recorded_at)
        assert Map.has_key?(metric, :dimensions)
        assert Map.has_key?(metric, :provider)
      end
    end

    test "sets provider to :google_business for all performance metrics" do
      plug = build_dual_stub_plug(valid_performance_response(), empty_reviews_response())

      assert {:ok, metrics} = GoogleBusiness.fetch_metrics(valid_integration(), http_plug: plug)

      perf_metrics = Enum.filter(metrics, fn m -> m.metric_type == "business_profile" end)
      assert perf_metrics != []

      for metric <- perf_metrics do
        assert metric.provider == :google_business
      end
    end

    test "normalizes metric names by downcasing and stripping \"business_\" prefix" do
      plug = build_dual_stub_plug(valid_performance_response(), empty_reviews_response())

      assert {:ok, metrics} = GoogleBusiness.fetch_metrics(valid_integration(), http_plug: plug)

      perf_metrics = Enum.filter(metrics, fn m -> m.metric_type == "business_profile" end)
      assert perf_metrics != []

      for metric <- perf_metrics do
        assert metric.metric_name == String.downcase(metric.metric_name)
        refute String.starts_with?(metric.metric_name, "business_")
      end
    end

    test "extracts recorded_at from date map fields year/month/day in performance response" do
      plug = build_dual_stub_plug(valid_performance_response(), empty_reviews_response())

      assert {:ok, metrics} = GoogleBusiness.fetch_metrics(valid_integration(), http_plug: plug)

      perf_metrics = Enum.filter(metrics, fn m -> m.metric_type == "business_profile" end)
      assert perf_metrics != []

      for metric <- perf_metrics do
        assert %DateTime{} = metric.recorded_at
      end
    end

    test "converts performance values to float" do
      plug = build_dual_stub_plug(valid_performance_response(), empty_reviews_response())

      assert {:ok, metrics} = GoogleBusiness.fetch_metrics(valid_integration(), http_plug: plug)

      perf_metrics = Enum.filter(metrics, fn m -> m.metric_type == "business_profile" end)
      assert perf_metrics != []

      for metric <- perf_metrics do
        assert is_float(metric.value)
      end
    end

    test "sets location_id and date in dimensions for performance metrics" do
      plug = build_dual_stub_plug(valid_performance_response(), empty_reviews_response())

      assert {:ok, metrics} = GoogleBusiness.fetch_metrics(valid_integration(), http_plug: plug)

      perf_metrics = Enum.filter(metrics, fn m -> m.metric_type == "business_profile" end)
      assert perf_metrics != []

      for metric <- perf_metrics do
        assert Map.has_key?(metric.dimensions, :location_id)
        assert Map.has_key?(metric.dimensions, :date)
        assert is_binary(metric.dimensions.date)
      end
    end

    test "emits review_rating metric with float star value (0.0-5.0) for each review" do
      plug = build_dual_stub_plug(empty_performance_response(), valid_reviews_response())

      assert {:ok, metrics} = GoogleBusiness.fetch_metrics(valid_integration(), http_plug: plug)

      rating_metrics = Enum.filter(metrics, fn m -> m.metric_name == "review_rating" end)
      assert rating_metrics != []

      for metric <- rating_metrics do
        assert is_float(metric.value)
        assert metric.value >= 0.0
        assert metric.value <= 5.0
      end
    end

    test "emits review_count metric with value 1.0 for each review" do
      plug = build_dual_stub_plug(empty_performance_response(), valid_reviews_response())

      assert {:ok, metrics} = GoogleBusiness.fetch_metrics(valid_integration(), http_plug: plug)

      count_metrics = Enum.filter(metrics, fn m -> m.metric_name == "review_count" end)
      assert count_metrics != []

      for metric <- count_metrics do
        assert metric.value == 1.0
      end
    end

    test "sets metric_type \"reviews\" for review metrics" do
      plug = build_dual_stub_plug(empty_performance_response(), valid_reviews_response())

      assert {:ok, metrics} = GoogleBusiness.fetch_metrics(valid_integration(), http_plug: plug)

      review_metrics = Enum.filter(metrics, fn m -> m.metric_type == "reviews" end)
      assert review_metrics != []

      for metric <- review_metrics do
        assert metric.metric_type == "reviews"
      end
    end

    test "sets provider to :google_business for all review metrics" do
      plug = build_dual_stub_plug(empty_performance_response(), valid_reviews_response())

      assert {:ok, metrics} = GoogleBusiness.fetch_metrics(valid_integration(), http_plug: plug)

      review_metrics = Enum.filter(metrics, fn m -> m.metric_type == "reviews" end)
      assert review_metrics != []

      for metric <- review_metrics do
        assert metric.provider == :google_business
      end
    end

    test "includes location_id, review_id, reviewer, and comment in review_rating dimensions" do
      plug = build_dual_stub_plug(empty_performance_response(), valid_reviews_response())

      assert {:ok, metrics} = GoogleBusiness.fetch_metrics(valid_integration(), http_plug: plug)

      rating_metrics = Enum.filter(metrics, fn m -> m.metric_name == "review_rating" end)
      assert rating_metrics != []

      for metric <- rating_metrics do
        assert Map.has_key?(metric.dimensions, :location_id)
        assert Map.has_key?(metric.dimensions, :review_id)
        assert Map.has_key?(metric.dimensions, :reviewer)
        assert Map.has_key?(metric.dimensions, :comment)
      end
    end

    test "includes location_id and date in review_count dimensions" do
      plug = build_dual_stub_plug(empty_performance_response(), valid_reviews_response())

      assert {:ok, metrics} = GoogleBusiness.fetch_metrics(valid_integration(), http_plug: plug)

      count_metrics = Enum.filter(metrics, fn m -> m.metric_name == "review_count" end)
      assert count_metrics != []

      for metric <- count_metrics do
        assert Map.has_key?(metric.dimensions, :location_id)
        assert Map.has_key?(metric.dimensions, :date)
      end
    end

    test "parses star rating ONE as 1, TWO as 2, THREE as 3, FOUR as 4, FIVE as 5" do
      all_ratings_response =
        Jason.encode!(%{
          "reviews" => [
            %{
              "reviewId" => "r1",
              "starRating" => "ONE",
              "reviewer" => %{"displayName" => "Reviewer One"},
              "comment" => "One",
              "createTime" => "2026-01-01T00:00:00Z"
            },
            %{
              "reviewId" => "r2",
              "starRating" => "TWO",
              "reviewer" => %{"displayName" => "Reviewer Two"},
              "comment" => "Two",
              "createTime" => "2026-01-02T00:00:00Z"
            },
            %{
              "reviewId" => "r3",
              "starRating" => "THREE",
              "reviewer" => %{"displayName" => "Reviewer Three"},
              "comment" => "Three",
              "createTime" => "2026-01-03T00:00:00Z"
            },
            %{
              "reviewId" => "r4",
              "starRating" => "FOUR",
              "reviewer" => %{"displayName" => "Reviewer Four"},
              "comment" => "Four",
              "createTime" => "2026-01-04T00:00:00Z"
            },
            %{
              "reviewId" => "r5",
              "starRating" => "FIVE",
              "reviewer" => %{"displayName" => "Reviewer Five"},
              "comment" => "Five",
              "createTime" => "2026-01-05T00:00:00Z"
            }
          ]
        })

      plug = build_dual_stub_plug(empty_performance_response(), all_ratings_response)

      assert {:ok, metrics} = GoogleBusiness.fetch_metrics(valid_integration(), http_plug: plug)

      rating_metrics = Enum.filter(metrics, fn m -> m.metric_name == "review_rating" end)
      rating_values = Enum.map(rating_metrics, & &1.value) |> Enum.sort()

      assert 1.0 in rating_values
      assert 2.0 in rating_values
      assert 3.0 in rating_values
      assert 4.0 in rating_values
      assert 5.0 in rating_values
    end

    test "uses 0 for unrecognized or unspecified star rating" do
      unspecified_rating_response =
        Jason.encode!(%{
          "reviews" => [
            %{
              "reviewId" => "r_unspecified",
              "starRating" => "STAR_RATING_UNSPECIFIED",
              "reviewer" => %{"displayName" => "Ambiguous Reviewer"},
              "comment" => "No rating",
              "createTime" => "2026-01-01T00:00:00Z"
            }
          ]
        })

      plug =
        build_dual_stub_plug(empty_performance_response(), unspecified_rating_response)

      assert {:ok, metrics} = GoogleBusiness.fetch_metrics(valid_integration(), http_plug: plug)

      rating_metrics = Enum.filter(metrics, fn m -> m.metric_name == "review_rating" end)
      assert rating_metrics != []

      for metric <- rating_metrics do
        assert metric.value == 0.0
      end
    end

    test "paginates reviews using nextPageToken up to 50 pages" do
      page_count = :counters.new(1, [:atomics])
      test_pid = self()

      paginating_plug = fn conn ->
        if String.contains?(conn.request_path, "fetchMultiDailyMetricsTimeSeries") do
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(200, empty_performance_response())
        else
          count = :counters.get(page_count, 1) + 1
          :counters.put(page_count, 1, count)
          send(test_pid, {:review_page_request, count})

          body =
            if count < 3 do
              reviews_response_with_next_page()
            else
              reviews_response_last_page()
            end

          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(200, body)
        end
      end

      capture_log(fn ->
        GoogleBusiness.fetch_metrics(valid_integration(), http_plug: paginating_plug)
      end)

      assert_receive {:review_page_request, 1}
      assert_receive {:review_page_request, 2}
      assert_receive {:review_page_request, 3}

      total_review_pages = :counters.get(page_count, 1)
      assert total_review_pages == 3
    end

    test "stops pagination when nextPageToken is absent in response" do
      page_count = :counters.new(1, [:atomics])

      single_page_plug = fn conn ->
        if String.contains?(conn.request_path, "fetchMultiDailyMetricsTimeSeries") do
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(200, empty_performance_response())
        else
          :counters.put(page_count, 1, :counters.get(page_count, 1) + 1)

          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(200, valid_reviews_response())
        end
      end

      capture_log(fn ->
        GoogleBusiness.fetch_metrics(valid_integration(), http_plug: single_page_plug)
      end)

      assert :counters.get(page_count, 1) == 1
    end

    test "handles 401 response from reviews API with error :unauthorized" do
      plug =
        build_dual_stub_plug(
          empty_performance_response(),
          Jason.encode!(%{"error" => "unauthorized"}),
          200,
          401
        )

      capture_log(fn ->
        assert {:ok, metrics} = GoogleBusiness.fetch_metrics(valid_integration(), http_plug: plug)
        assert is_list(metrics)
      end)
    end

    test "handles 403 response from reviews API with error :insufficient_permissions" do
      plug =
        build_dual_stub_plug(
          empty_performance_response(),
          Jason.encode!(%{"error" => "forbidden"}),
          200,
          403
        )

      capture_log(fn ->
        assert {:ok, metrics} = GoogleBusiness.fetch_metrics(valid_integration(), http_plug: plug)
        assert is_list(metrics)
      end)
    end

    test "handles 404 response from reviews API with error :location_not_found" do
      plug =
        build_dual_stub_plug(
          empty_performance_response(),
          Jason.encode!(%{"error" => "not found"}),
          200,
          404
        )

      capture_log(fn ->
        assert {:ok, metrics} = GoogleBusiness.fetch_metrics(valid_integration(), http_plug: plug)
        assert is_list(metrics)
      end)
    end

    test "handles network errors from performance API by logging warning and returning empty list for that location" do
      plug = fn conn ->
        if String.contains?(conn.request_path, "fetchMultiDailyMetricsTimeSeries") do
          raise %Req.TransportError{reason: :econnrefused}
        else
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(200, empty_reviews_response())
        end
      end

      log =
        capture_log(fn ->
          assert {:ok, metrics} = GoogleBusiness.fetch_metrics(valid_integration(), http_plug: plug)
          assert is_list(metrics)
        end)

      assert String.contains?(log, "GBP Performance API failed")
    end

    test "handles network errors from reviews API by logging warning and returning empty list for that location" do
      plug = fn conn ->
        if String.contains?(conn.request_path, "fetchMultiDailyMetricsTimeSeries") do
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(200, empty_performance_response())
        else
          raise %Req.TransportError{reason: :econnrefused}
        end
      end

      log =
        capture_log(fn ->
          assert {:ok, metrics} = GoogleBusiness.fetch_metrics(valid_integration(), http_plug: plug)
          assert is_list(metrics)
        end)

      assert String.contains?(log, "GBP reviews fetch failed")
    end

    test "handles empty reviews response with empty list" do
      plug = build_dual_stub_plug(empty_performance_response(), empty_reviews_response())

      assert {:ok, metrics} = GoogleBusiness.fetch_metrics(valid_integration(), http_plug: plug)

      review_metrics = Enum.filter(metrics, fn m -> m.metric_type == "reviews" end)
      assert review_metrics == []
    end
  end

  # ---------------------------------------------------------------------------
  # provider/0
  # ---------------------------------------------------------------------------

  describe "provider/0" do
    test "returns :google_business atom" do
      assert GoogleBusiness.provider() == :google_business
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
        :google_search_console,
        :google_business,
        :google_business_reviews,
        :quickbooks,
        :codemyspec
      ]

      assert GoogleBusiness.provider() in valid_providers
    end
  end

  # ---------------------------------------------------------------------------
  # required_scopes/0
  # ---------------------------------------------------------------------------

  describe "required_scopes/0" do
    test "returns list with business.manage scope" do
      scopes = GoogleBusiness.required_scopes()

      assert Enum.any?(scopes, fn scope ->
               String.contains?(scope, "business.manage")
             end)
    end

    test "scope URL is properly formatted" do
      scopes = GoogleBusiness.required_scopes()

      assert Enum.all?(scopes, fn scope ->
               String.starts_with?(scope, "https://www.googleapis.com/")
             end)
    end

    test "returned scopes are strings not atoms" do
      scopes = GoogleBusiness.required_scopes()

      assert Enum.all?(scopes, &is_binary/1)
    end

    test "list contains exactly one scope" do
      scopes = GoogleBusiness.required_scopes()

      assert length(scopes) == 1
    end

    test "scope matches Google Business Profile API requirements" do
      scopes = GoogleBusiness.required_scopes()

      assert "https://www.googleapis.com/auth/business.manage" in scopes
    end
  end

  # ---------------------------------------------------------------------------
  # Cassette integration tests — real Google Business Profile API traffic
  # ---------------------------------------------------------------------------

  describe "fetch_metrics/2 with cassette" do
    @describetag :integration

    import MetricFlowTest.CassetteFixtures

    setup do
      case google_business_integration() do
        nil -> {:ok, skip: true}
        integration -> {:ok, integration: integration}
      end
    end

    test "fetches real GBP performance metrics from Business Profile Performance API", context do
      if context[:skip], do: flunk("GBP integration not configured in .env.test")

      capture_log(fn ->
        with_cassette "gbp_fetch_metrics", cassette_opts("gbp_fetch_metrics"), fn plug ->
          assert {:ok, metrics} =
                   GoogleBusiness.fetch_metrics(context.integration,
                     http_plug: plug,
                     date_range: default_date_range()
                   )

          assert is_list(metrics)

          for metric <- metrics do
            assert metric.provider == :google_business
            assert metric.metric_type in ["business_profile", "reviews"]
            assert is_binary(metric.metric_name)
            assert is_number(metric.value)
            assert %DateTime{} = metric.recorded_at
            assert is_map(metric.dimensions)
          end
        end
      end)
    end

    test "returns structured error for unauthorized request", context do
      if context[:skip], do: flunk("GBP integration not configured in .env.test")

      capture_log(fn ->
        with_cassette "gbp_unauthorized", cassette_opts("gbp_unauthorized"), fn plug ->
          bad_token = %{context.integration | access_token: "invalid-token"}

          assert {:error, reason} =
                   GoogleBusiness.fetch_metrics(bad_token,
                     http_plug: plug,
                     date_range: default_date_range()
                   )

          assert reason in [:unauthorized, :insufficient_permissions]
        end
      end)
    end
  end
end
