defmodule MetricFlow.DataSync.DataProviders.GoogleBusiness do
  @moduledoc """
  Google Business Profile data provider implementing the DataProviders.Behaviour contract.

  Fetches two categories of data for each selected location:

  1. **Performance metrics** from the Business Profile Performance API v1:
     impressions (desktop/mobile, maps/search), conversations, direction
     requests, call clicks, website clicks, bookings, food orders, food menu clicks.

  2. **Reviews** from the My Business v4 API: individual review records with
     star ratings, reviewer info, and comments.

  Accepts an `http_plug` option for dependency injection during tests.
  """

  @behaviour MetricFlow.DataSync.DataProviders.Behaviour

  require Logger

  alias MetricFlow.Integrations.Integration

  @performance_api_base "https://businessprofileperformance.googleapis.com/v1"
  @reviews_api_base "https://mybusiness.googleapis.com/v4"
  @max_review_pages 50
  @review_page_size 100

  @daily_metrics [
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

  # ---------------------------------------------------------------------------
  # Behaviour callbacks
  # ---------------------------------------------------------------------------

  @spec fetch_metrics(Integration.t(), keyword()) :: {:ok, list(map())} | {:error, term()}
  def fetch_metrics(%Integration{} = integration, opts \\ []) do
    with :ok <- check_not_expired(integration),
         {:ok, location_ids} <- resolve_locations(integration) do
      metrics =
        Enum.flat_map(location_ids, fn location_id ->
          performance = fetch_performance_metrics(integration, location_id, opts)
          reviews = fetch_review_metrics(integration, location_id, opts)
          performance ++ reviews
        end)

      {:ok, metrics}
    end
  end

  @spec provider() :: :google_business
  def provider, do: :google_business

  @spec required_scopes() :: list(String.t())
  def required_scopes do
    ["https://www.googleapis.com/auth/business.manage"]
  end

  # ---------------------------------------------------------------------------
  # Private — config resolution
  # ---------------------------------------------------------------------------

  defp check_not_expired(%Integration{} = integration) do
    if Integration.expired?(integration), do: {:error, :unauthorized}, else: :ok
  end

  defp resolve_locations(%Integration{provider_metadata: meta}) do
    case get_in(meta || %{}, ["included_locations"]) do
      ids when is_list(ids) and ids != [] -> {:ok, ids}
      _ -> {:error, :no_locations_configured}
    end
  end

  defp resolve_date_range(opts) do
    case Keyword.get(opts, :date_range) do
      {start_date, end_date} -> {start_date, end_date}
      nil ->
        today = Date.utc_today()
        {Date.add(today, -548), Date.add(today, -1)}
    end
  end

  # ---------------------------------------------------------------------------
  # Private — Performance metrics (Business Profile Performance API v1)
  # ---------------------------------------------------------------------------

  defp fetch_performance_metrics(integration, location_id, opts) do
    {start_date, end_date} = resolve_date_range(opts)

    # The Performance API uses the location name without "accounts/X/" prefix
    # location_id format: "accounts/123/locations/456" -> "locations/456"
    perf_location = extract_location_path(location_id)

    url = build_performance_url(perf_location, start_date, end_date)
    headers = [{"authorization", "Bearer #{integration.access_token}"}]

    req_opts =
      [method: :get, url: url, headers: headers]
      |> maybe_put_plug(opts)

    try do
      response = Req.request!(req_opts)
      handle_performance_response(response, location_id)
    rescue
      e ->
        Logger.warning("GBP Performance API failed for #{location_id}: #{Exception.message(e)}")
        []
    end
  end

  defp extract_location_path(location_id) do
    # "accounts/123/locations/456" -> "locations/456"
    case String.split(location_id, "/") do
      ["accounts", _account_id, "locations", loc_id] -> "locations/#{loc_id}"
      _ -> location_id
    end
  end

  defp build_performance_url(location_path, start_date, end_date) do
    metrics_param = Enum.join(@daily_metrics, "&dailyMetrics=")

    "#{@performance_api_base}/#{location_path}:fetchMultiDailyMetricsTimeSeries" <>
      "?dailyMetrics=#{metrics_param}" <>
      "&dailyRange.startDate.year=#{start_date.year}" <>
      "&dailyRange.startDate.month=#{start_date.month}" <>
      "&dailyRange.startDate.day=#{start_date.day}" <>
      "&dailyRange.endDate.year=#{end_date.year}" <>
      "&dailyRange.endDate.month=#{end_date.month}" <>
      "&dailyRange.endDate.day=#{end_date.day}"
  end

  defp handle_performance_response(%Req.Response{status: 200, body: body}, location_id) when is_map(body) do
    body
    |> Map.get("multiDailyMetricTimeSeries", [])
    |> Enum.flat_map(fn metric_group ->
      metric_group
      |> Map.get("dailyMetricTimeSeries", [])
      |> Enum.flat_map(fn daily_metric ->
        metric_name = Map.get(daily_metric, "dailyMetric", "UNKNOWN")
        dated_values = get_in(daily_metric, ["timeSeries", "datedValues"])

        (dated_values || [])
        |> Enum.filter(&is_map/1)
        |> Enum.filter(&Map.has_key?(&1, "date"))
        |> Enum.map(fn data_point ->
          date_map = data_point["date"]
          recorded_at = parse_date_map(date_map)
          value = parse_int_value(data_point["value"] || "0")
          date_str = Date.to_iso8601(DateTime.to_date(recorded_at))

          normalized_name = normalize_metric_name(metric_name)

          %{
            metric_type: "business_profile",
            metric_name: normalized_name,
            normalized_metric_name: MetricFlow.Metrics.NormalizedMetric.normalize(:google_business, normalized_name),
            value: value * 1.0,
            recorded_at: recorded_at,
            dimensions: %{
              location_id: location_id,
              raw_metric: metric_name,
              date: date_str
            },
            provider: :google_business
          }
        end)
      end)
    end)
  end

  defp handle_performance_response(%Req.Response{status: status, body: body}, location_id) do
    Logger.warning("GBP Performance API returned #{status} for #{location_id}: #{inspect(body)}")
    []
  end

  defp parse_date_map(%{"year" => y, "month" => m, "day" => d}) do
    case Date.new(y, m, d) do
      {:ok, date} -> DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
      _ -> DateTime.utc_now()
    end
  end

  defp parse_date_map(_), do: DateTime.utc_now()

  defp parse_int_value(val) when is_integer(val), do: val
  defp parse_int_value(val) when is_binary(val) do
    case Integer.parse(val) do
      {n, _} -> n
      :error -> 0
    end
  end
  defp parse_int_value(_), do: 0

  defp normalize_metric_name(name) do
    name
    |> String.downcase()
    |> String.replace("business_", "")
  end

  # ---------------------------------------------------------------------------
  # Private — Reviews (My Business v4 API)
  # ---------------------------------------------------------------------------

  defp fetch_review_metrics(integration, location_id, opts) do
    case fetch_review_pages(integration, location_id, opts, nil, [], @max_review_pages) do
      {:ok, reviews} -> transform_reviews(reviews, location_id)
      {:error, reason} ->
        Logger.warning("GBP reviews fetch failed for #{location_id}: #{inspect(reason)}")
        []
    end
  end

  defp fetch_review_pages(_integration, _location_id, _opts, _page_token, acc, 0) do
    {:ok, acc}
  end

  defp fetch_review_pages(integration, location_id, opts, page_token, acc, pages_remaining) do
    case execute_review_request(integration, location_id, opts, page_token) do
      {:ok, reviews, nil} ->
        {:ok, acc ++ reviews}

      {:ok, reviews, next_token} ->
        fetch_review_pages(integration, location_id, opts, next_token, acc ++ reviews, pages_remaining - 1)

      {:error, _} = err ->
        err
    end
  end

  defp execute_review_request(integration, location_id, opts, page_token) do
    url = build_reviews_url(location_id, page_token)
    headers = [{"authorization", "Bearer #{integration.access_token}"}]

    req_opts =
      [method: :get, url: url, headers: headers]
      |> maybe_put_plug(opts)

    try do
      response = Req.request!(req_opts)
      handle_review_response(response)
    rescue
      e ->
        Logger.error("GBP Reviews API request failed: #{Exception.message(e)}")
        {:error, {:network_error, Exception.message(e)}}
    end
  end

  defp build_reviews_url(location_id, nil) do
    "#{@reviews_api_base}/#{location_id}/reviews?pageSize=#{@review_page_size}&orderBy=updateTime+desc"
  end

  defp build_reviews_url(location_id, page_token) do
    "#{@reviews_api_base}/#{location_id}/reviews?pageSize=#{@review_page_size}&orderBy=updateTime+desc&pageToken=#{page_token}"
  end

  defp handle_review_response(%Req.Response{status: 200, body: body}) when is_map(body) do
    reviews = Map.get(body, "reviews", [])
    next_token = Map.get(body, "nextPageToken")
    {:ok, reviews, next_token}
  end

  defp handle_review_response(%Req.Response{status: 200, body: body}) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} -> handle_review_response(%Req.Response{status: 200, body: decoded})
      {:error, _} -> {:error, :malformed_response}
    end
  end

  defp handle_review_response(%Req.Response{status: 401}), do: {:error, :unauthorized}
  defp handle_review_response(%Req.Response{status: 403}), do: {:error, :insufficient_permissions}
  defp handle_review_response(%Req.Response{status: 404}), do: {:error, :location_not_found}

  defp handle_review_response(%Req.Response{status: status, body: body}) do
    Logger.warning("GBP Reviews API returned #{status}: #{inspect(body)}")
    {:error, :bad_request}
  end

  # ---------------------------------------------------------------------------
  # Private — review transformation
  # ---------------------------------------------------------------------------

  defp transform_reviews(reviews, location_id) do
    Enum.flat_map(reviews, fn review ->
      recorded_at = parse_review_time(review)
      star_rating = parse_star_rating(Map.get(review, "starRating", "STAR_RATING_UNSPECIFIED"))
      review_id = Map.get(review, "reviewId", "")

      [
        %{
          metric_type: "reviews",
          metric_name: "review_rating",
          normalized_metric_name: "reviews",
          value: star_rating * 1.0,
          recorded_at: recorded_at,
          dimensions: %{
            location_id: location_id,
            review_id: review_id,
            reviewer: get_in(review, ["reviewer", "displayName"]) || "Anonymous",
            comment: Map.get(review, "comment") || ""
          },
          provider: :google_business
        },
        %{
          metric_type: "reviews",
          metric_name: "review_count",
          normalized_metric_name: "reviews",
          value: 1.0,
          recorded_at: recorded_at,
          dimensions: %{
            location_id: location_id,
            date: Date.to_iso8601(DateTime.to_date(recorded_at))
          },
          provider: :google_business
        }
      ]
    end)
  end

  defp parse_star_rating("ONE"), do: 1
  defp parse_star_rating("TWO"), do: 2
  defp parse_star_rating("THREE"), do: 3
  defp parse_star_rating("FOUR"), do: 4
  defp parse_star_rating("FIVE"), do: 5
  defp parse_star_rating(_), do: 0

  defp parse_review_time(%{"createTime" => time_str}) when is_binary(time_str) do
    case DateTime.from_iso8601(time_str) do
      {:ok, dt, _} -> dt
      _ -> DateTime.utc_now()
    end
  end

  defp parse_review_time(%{"updateTime" => time_str}) when is_binary(time_str) do
    case DateTime.from_iso8601(time_str) do
      {:ok, dt, _} -> dt
      _ -> DateTime.utc_now()
    end
  end

  defp parse_review_time(_), do: DateTime.utc_now()

  # ---------------------------------------------------------------------------
  # Private — shared helpers
  # ---------------------------------------------------------------------------

  defp maybe_put_plug(req_opts, opts) do
    case Keyword.get(opts, :http_plug) do
      nil -> req_opts
      plug -> Keyword.put(req_opts, :plug, plug)
    end
  end
end
