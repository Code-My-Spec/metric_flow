defmodule MetricFlow.DataSync.DataProviders.GoogleAds do
  @moduledoc """
  Google Ads data provider implementation using Google Ads API v16+ searchStream endpoint.

  Fetches campaign performance metrics including impressions, clicks, cost, conversions,
  ctr, average_cpc, and conversions_value with dimension breakdowns by campaign_name,
  ad_group_name, and date. Uses GAQL (Google Ads Query Language) for data retrieval.

  Transforms API response to unified metric format with provider :google_ads.
  Handles customer account selection, date range filtering, and multi-page responses
  via pageToken pagination.
  """

  @behaviour MetricFlow.DataSync.DataProviders.Behaviour

  alias MetricFlow.Integrations.Integration

  @base_url "https://googleads.googleapis.com/v23/customers"
  @default_date_range_days 548
  @max_pages 100

  @impl true
  @spec provider() :: :google_ads
  def provider, do: :google_ads

  @impl true
  @spec required_scopes() :: list(String.t())
  def required_scopes, do: ["https://www.googleapis.com/auth/adwords"]

  @impl true
  @spec fetch_metrics(Integration.t(), keyword()) :: {:ok, list(map())} | {:error, term()}
  def fetch_metrics(%Integration{} = integration, opts \\ []) do
    with false <- Integration.expired?(integration),
         {:ok, customer_id} <- resolve_customer_id(integration, opts) do
      date_range = Keyword.get(opts, :date_range, default_date_range())
      breakdown = Keyword.get(opts, :breakdown, :campaign)
      http_plug = Keyword.get(opts, :http_plug)

      login_customer_id = resolve_login_customer_id(integration, opts)
      do_fetch(integration.access_token, customer_id, login_customer_id, date_range, breakdown, http_plug)
    else
      true -> {:error, :unauthorized}
      {:error, reason} -> {:error, reason}
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp resolve_customer_id(integration, opts) do
    cond do
      Keyword.has_key?(opts, :customer_id) ->
        {:ok, Keyword.fetch!(opts, :customer_id)}

      match?(%{"customer_id" => _}, integration.provider_metadata) ->
        {:ok, integration.provider_metadata["customer_id"]}

      true ->
        {:error, :missing_customer_id}
    end
  end

  defp resolve_login_customer_id(integration, opts) do
    Keyword.get(opts, :login_customer_id) ||
      get_in(integration.provider_metadata, ["login_customer_id"]) ||
      Application.get_env(:metric_flow, :google_ads_login_customer_id)
  end

  defp default_date_range do
    today = Date.utc_today()
    start_date = Date.add(today, -@default_date_range_days)
    {start_date, today}
  end

  defp do_fetch(access_token, customer_id, login_customer_id, {start_date, end_date}, breakdown, http_plug) do
    url = "#{@base_url}/#{customer_id}/googleAds:searchStream"
    query = build_gaql_query(start_date, end_date, breakdown)
    developer_token = Application.get_env(:metric_flow, :google_ads_developer_token, "")

    headers =
      [
        {"Authorization", "Bearer #{access_token}"},
        {"Content-Type", "application/json"},
        {"developer-token", developer_token}
      ]
      |> maybe_add_login_customer_id(login_customer_id)

    body = Jason.encode!(%{"query" => query})

    req_opts =
      [method: :post, url: url, headers: headers, body: body]
      |> maybe_add_plug(http_plug)

    result =
      try do
        Req.request(req_opts)
      rescue
        e -> {:error, {:network_error, e}}
      end

    case handle_http_result(result) do
      {:ok, first_page_rows, next_page_token} ->
        case fetch_remaining_pages(
               access_token,
               customer_id,
               login_customer_id,
               query,
               developer_token,
               http_plug,
               first_page_rows,
               next_page_token,
               1
             ) do
          {:ok, all_rows} ->
            metrics = Enum.flat_map(all_rows, &transform_row(&1, customer_id))
            {:ok, metrics}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp fetch_remaining_pages(
         _access_token,
         _customer_id,
         _login_customer_id,
         _query,
         _developer_token,
         _http_plug,
         rows,
         nil,
         _page_count
       ) do
    {:ok, rows}
  end

  defp fetch_remaining_pages(
         _access_token,
         _customer_id,
         _login_customer_id,
         _query,
         _developer_token,
         _http_plug,
         rows,
         _page_token,
         page_count
       )
       when page_count >= @max_pages do
    {:ok, rows}
  end

  defp fetch_remaining_pages(
         access_token,
         customer_id,
         login_customer_id,
         query,
         developer_token,
         http_plug,
         accumulated_rows,
         page_token,
         page_count
       ) do
    url = "#{@base_url}/#{customer_id}/googleAds:searchStream"

    headers =
      [
        {"Authorization", "Bearer #{access_token}"},
        {"Content-Type", "application/json"},
        {"developer-token", developer_token}
      ]
      |> maybe_add_login_customer_id(login_customer_id)

    body = Jason.encode!(%{"query" => query, "pageToken" => page_token})

    req_opts =
      [method: :post, url: url, headers: headers, body: body]
      |> maybe_add_plug(http_plug)

    result =
      try do
        Req.request(req_opts)
      rescue
        e -> {:error, {:network_error, e}}
      end

    case handle_http_result(result) do
      {:ok, page_rows, next_token} ->
        fetch_remaining_pages(
          access_token,
          customer_id,
          login_customer_id,
          query,
          developer_token,
          http_plug,
          accumulated_rows ++ page_rows,
          next_token,
          page_count + 1
        )

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_gaql_query(start_date, end_date, breakdown) do
    dimensions = build_dimensions(breakdown)
    start_str = Date.to_iso8601(start_date)
    end_str = Date.to_iso8601(end_date)

    select_fields =
      [
        "metrics.impressions",
        "metrics.clicks",
        "metrics.cost_micros",
        "metrics.conversions",
        "metrics.ctr",
        "metrics.average_cpc",
        "metrics.conversions_value",
        "campaign.name",
        "segments.date"
      ] ++ dimensions

    select_clause = Enum.join(select_fields, ", ")

    from_clause =
      if breakdown == :ad_group do
        "ad_group"
      else
        "campaign"
      end

    """
    SELECT #{select_clause}
    FROM #{from_clause}
    WHERE segments.date BETWEEN '#{start_str}' AND '#{end_str}'
    ORDER BY segments.date DESC
    """
    |> String.trim()
  end

  defp build_dimensions(:ad_group), do: ["ad_group.name"]
  defp build_dimensions(_), do: []

  defp handle_http_result({:ok, %{status: 200, body: response_body}}) do
    parse_streaming_response(response_body)
  end

  defp handle_http_result({:ok, %{status: 401}}), do: {:error, :unauthorized}
  defp handle_http_result({:ok, %{status: 403}}), do: {:error, :insufficient_permissions}
  defp handle_http_result({:ok, %{status: 404}}), do: {:error, :customer_not_found}

  defp handle_http_result({:ok, %{status: 400, body: body}}) do
    message = extract_error_message(body)
    {:error, {:bad_request, message}}
  end

  defp handle_http_result({:ok, %{status: 429}}), do: {:error, :rate_limited}
  defp handle_http_result({:ok, %{status: 500}}), do: {:error, :internal_server_error}
  defp handle_http_result({:ok, %{status: status}}) when status >= 500, do: {:error, :server_error}
  defp handle_http_result({:error, :malformed_response}), do: {:error, :malformed_response}

  defp handle_http_result({:error, {:network_error, reason}}),
    do: {:error, {:network_error, reason}}

  defp handle_http_result({:error, reason}), do: {:error, {:network_error, reason}}

  defp parse_streaming_response(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} -> parse_streaming_response(decoded)
      {:error, _} -> {:error, :malformed_response}
    end
  end

  defp parse_streaming_response(pages) when is_list(pages) do
    rows =
      Enum.flat_map(pages, fn page ->
        Map.get(page, "results", []) || []
      end)

    next_page_token =
      pages
      |> List.last()
      |> case do
        nil -> nil
        last_page -> Map.get(last_page, "nextPageToken")
      end

    {:ok, rows, next_page_token}
  end

  defp parse_streaming_response(_), do: {:error, :malformed_response}

  defp extract_error_message(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, %{"error" => %{"message" => msg}}} -> msg
      {:ok, %{"error" => error}} when is_binary(error) -> error
      _ -> body
    end
  end

  defp extract_error_message(body) when is_map(body) do
    get_in(body, ["error", "message"]) || inspect(body)
  end

  defp extract_error_message(body), do: inspect(body)

  defp transform_row(row, customer_id) do
    metrics_raw = Map.get(row, "metrics", %{}) || %{}
    campaign = Map.get(row, "campaign")
    ad_group = Map.get(row, "adGroup")
    segments = Map.get(row, "segments", %{}) || %{}

    campaign_name = get_in(campaign, ["name"])
    ad_group_name = get_in(ad_group, ["name"])
    date_str = Map.get(segments, "date")
    recorded_at = parse_date(date_str)

    base_metadata = %{
      customer_id: customer_id,
      campaign_name: campaign_name,
      ad_group_name: ad_group_name
    }

    impressions = parse_integer(Map.get(metrics_raw, "impressions", "0"))
    clicks = parse_integer(Map.get(metrics_raw, "clicks", "0"))
    cost_micros = parse_integer(Map.get(metrics_raw, "costMicros", "0"))
    cost_dollars = cost_micros / 1_000_000
    conversions = parse_float(Map.get(metrics_raw, "conversions", "0.0"))
    ctr = parse_float(Map.get(metrics_raw, "ctr", 0.0))
    average_cpc_micros = parse_integer(Map.get(metrics_raw, "averageCpc", "0"))
    average_cpc = average_cpc_micros / 1_000_000
    conversions_value = parse_float(Map.get(metrics_raw, "conversionsValue", "0.0"))

    [
      build_metric("advertising", "impressions", impressions, recorded_at, base_metadata),
      build_metric("advertising", "clicks", clicks, recorded_at, base_metadata),
      build_metric("advertising", "cost", cost_dollars, recorded_at, base_metadata),
      build_metric("advertising", "conversions", conversions, recorded_at, base_metadata),
      build_metric("advertising", "ctr", ctr, recorded_at, base_metadata),
      build_metric("advertising", "average_cpc", average_cpc, recorded_at, base_metadata),
      build_metric("advertising", "conversions_value", conversions_value, recorded_at, base_metadata)
    ]
  end

  defp build_metric(metric_type, metric_name, value, recorded_at, metadata) do
    %{
      metric_type: metric_type,
      metric_name: metric_name,
      value: value,
      recorded_at: recorded_at,
      metadata: metadata,
      provider: :google_ads
    }
  end

  defp parse_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> int
      {int, _} -> int
      :error -> 0
    end
  end

  defp parse_integer(value) when is_integer(value), do: value
  defp parse_integer(value) when is_float(value), do: trunc(value)
  defp parse_integer(_), do: 0

  defp parse_float(value) when is_binary(value) do
    case Float.parse(value) do
      {float, ""} -> float
      {float, _} -> float
      :error -> 0.0
    end
  end

  defp parse_float(value) when is_float(value), do: value
  defp parse_float(value) when is_integer(value), do: value / 1
  defp parse_float(_), do: 0.0

  defp parse_date(nil), do: DateTime.utc_now()

  defp parse_date(date_str) when is_binary(date_str) do
    case Date.from_iso8601(date_str) do
      {:ok, date} -> DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
      {:error, _} -> DateTime.utc_now()
    end
  end

  defp parse_date(_), do: DateTime.utc_now()

  defp maybe_add_plug(opts, nil), do: opts
  defp maybe_add_plug(opts, plug), do: Keyword.put(opts, :plug, plug)

  defp maybe_add_login_customer_id(headers, nil), do: headers
  defp maybe_add_login_customer_id(headers, id), do: headers ++ [{"login-customer-id", id}]
end
