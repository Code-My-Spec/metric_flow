defmodule MetricFlow.DataSync.DataProviders.FacebookAds do
  @moduledoc """
  Facebook Ads provider implementation using Facebook Marketing API v18+.

  Fetches ad campaign performance metrics including impressions, clicks, spend,
  conversions, cpm, cpc, ctr, and conversion_rate with dimension breakdowns by
  campaign_name, adset_name, and date. Uses the Ad Insights endpoint for data
  retrieval.

  Transforms API responses to unified metric format. Handles ad account
  selection, cursor-based pagination, and date range filtering. Stores metrics
  with provider :facebook_ads.
  """

  @behaviour MetricFlow.DataSync.DataProviders.Behaviour

  alias MetricFlow.Integrations.Integration

  @api_version "v22.0"
  @api_base_url "https://graph.facebook.com"
  @default_date_range_days 548
  @page_limit 100

  @conversion_action_types ["purchase", "offsite_conversion"]

  @metric_fields "impressions,clicks,spend,cpm,cpc,ctr,actions"

  # ---------------------------------------------------------------------------
  # Behaviour callbacks
  # ---------------------------------------------------------------------------

  @doc """
  Returns the provider atom identifier for this data provider.
  """
  @spec provider() :: :facebook_ads
  @impl true
  def provider, do: :facebook_ads

  @doc """
  Returns the OAuth scopes required for fetching Facebook Ads metrics.
  """
  @spec required_scopes() :: list(String.t())
  @impl true
  def required_scopes, do: ["ads_read", "ads_management"]

  @doc """
  Fetches Facebook Ads metrics for an integration using OAuth tokens.

  Accepts the following options:
  - `:ad_account_id` - Override the ad account ID (falls back to provider_metadata)
  - `:date_range` - A `{start_date, end_date}` tuple of `Date.t()` values
  - `:breakdown` - `:adset` to include adset-level dimensions
  - `:http_plug` - A Plug function for test injection (Req plug option)
  """
  @spec fetch_metrics(Integration.t(), keyword()) :: {:ok, list(map())} | {:error, term()}
  @impl true
  def fetch_metrics(%Integration{} = integration, opts \\ []) do
    with false <- Integration.expired?(integration),
         {:ok, ad_account_id} <- resolve_ad_account_id(integration, opts) do
      normalized_id = normalize_ad_account_id(ad_account_id)
      date_range = Keyword.get(opts, :date_range, default_date_range())
      breakdown = Keyword.get(opts, :breakdown, :campaign)
      http_plug = Keyword.get(opts, :http_plug)

      do_fetch(integration.access_token, normalized_id, date_range, breakdown, http_plug, nil)
    else
      true -> {:error, :unauthorized}
      {:error, reason} -> {:error, reason}
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp resolve_ad_account_id(integration, opts) do
    meta = integration.provider_metadata || %{}

    cond do
      Keyword.has_key?(opts, :ad_account_id) ->
        {:ok, to_string(Keyword.fetch!(opts, :ad_account_id))}

      is_binary(meta["ad_account_id"]) and meta["ad_account_id"] != "" ->
        {:ok, meta["ad_account_id"]}

      # Fallback: account selection may have saved under "property_id" before the key fix
      is_binary(meta["property_id"]) and meta["property_id"] != "" ->
        {:ok, meta["property_id"]}

      true ->
        {:error, :missing_ad_account_id}
    end
  end

  defp normalize_ad_account_id("act_" <> _ = id), do: id
  defp normalize_ad_account_id(id), do: "act_#{id}"

  defp default_date_range do
    today = Date.utc_today()
    start_date = Date.add(today, -@default_date_range_days)
    {start_date, today}
  end

  defp do_fetch(access_token, ad_account_id, date_range, breakdown, http_plug, after_cursor) do
    require Logger
    url = "#{@api_base_url}/#{@api_version}/#{ad_account_id}/insights"
    Logger.info("FacebookAds fetching: #{url} date_range=#{inspect(date_range)}")

    fields = build_fields(breakdown)
    level = if breakdown == :adset, do: "adset", else: "campaign"
    {since, until_date} = date_range

    time_range =
      Jason.encode!(%{
        "since" => Date.to_iso8601(since),
        "until" => Date.to_iso8601(until_date)
      })

    params =
      [
        {"access_token", access_token},
        {"fields", fields},
        {"time_range", time_range},
        {"level", level},
        {"limit", to_string(@page_limit)}
      ]
      |> maybe_add_after_cursor(after_cursor)

    req_opts =
      [method: :get, url: url, params: params, retry: false]
      |> maybe_add_plug(http_plug)

    result =
      try do
        Req.request(req_opts)
      rescue
        _e in Jason.DecodeError -> {:error, :malformed_response}
        e -> {:error, {:network_error, e}}
      end

    handle_http_result(result, ad_account_id, access_token, date_range, breakdown, http_plug)
  end

  defp build_fields(:adset), do: "campaign_name,adset_name,date_start,#{@metric_fields}"
  defp build_fields(_), do: "campaign_name,date_start,#{@metric_fields}"

  defp maybe_add_after_cursor(params, nil), do: params
  defp maybe_add_after_cursor(params, cursor), do: params ++ [{"after", cursor}]

  defp maybe_add_plug(opts, nil), do: opts
  defp maybe_add_plug(opts, plug), do: Keyword.put(opts, :plug, plug)

  defp handle_http_result(
         {:ok, %{status: 200, body: body}},
         ad_account_id,
         access_token,
         date_range,
         breakdown,
         http_plug
       ) do
    with {:ok, decoded} <- decode_body(body),
         :ok <- check_for_oauth_error(decoded) do
      data = Map.get(decoded, "data", [])
      require Logger
      Logger.info("FacebookAds API returned #{length(data)} rows for #{ad_account_id}")
      if data == [], do: Logger.info("FacebookAds API full response: #{inspect(decoded)}")
      metrics = Enum.flat_map(data, &transform_row(&1, ad_account_id))
      fetch_next_page(decoded, metrics, access_token, ad_account_id, date_range, breakdown, http_plug)
    end
  end

  defp handle_http_result({:ok, %{status: 401}}, _, _, _, _, _), do: {:error, :unauthorized}
  defp handle_http_result({:ok, %{status: 403}}, _, _, _, _, _), do: {:error, :insufficient_permissions}
  defp handle_http_result({:ok, %{status: 429}}, _, _, _, _, _), do: {:error, :rate_limited}

  defp handle_http_result({:ok, %{status: 400, body: body}}, _, _, _, _, _) do
    case decode_body(body) do
      {:ok, %{"error" => %{"code" => 190}}} -> {:error, :invalid_token}
      {:ok, %{"error" => error_details}} -> {:error, {:facebook_api_error, error_details}}
      _ -> {:error, :bad_request}
    end
  end

  defp handle_http_result({:error, :malformed_response}, _, _, _, _, _),
    do: {:error, :malformed_response}

  defp handle_http_result({:error, {:network_error, reason}}, _, _, _, _, _),
    do: {:error, {:network_error, reason}}

  defp handle_http_result({:error, reason}, _, _, _, _, _),
    do: {:error, {:network_error, reason}}

  defp fetch_next_page(decoded, metrics, access_token, ad_account_id, date_range, breakdown, http_plug) do
    case get_paging_next(decoded) do
      nil ->
        {:ok, metrics}

      next_cursor ->
        case do_fetch(access_token, ad_account_id, date_range, breakdown, http_plug, next_cursor) do
          {:ok, next_metrics} -> {:ok, metrics ++ next_metrics}
          error -> error
        end
    end
  end

  defp decode_body(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} -> {:ok, decoded}
      {:error, _} -> {:error, :malformed_response}
    end
  end

  defp decode_body(body) when is_map(body), do: {:ok, body}
  defp decode_body(_), do: {:error, :malformed_response}

  defp check_for_oauth_error(%{"error" => %{"code" => 190}}), do: {:error, :invalid_token}

  defp check_for_oauth_error(%{"error" => error_details}),
    do: {:error, {:facebook_api_error, error_details}}

  defp check_for_oauth_error(_), do: :ok

  defp get_paging_next(decoded) do
    case get_in(decoded, ["paging", "next"]) do
      nil -> nil
      _next_url -> get_in(decoded, ["paging", "cursors", "after"])
    end
  end

  defp transform_row(row, ad_account_id) do
    recorded_at = parse_date_start(row["date_start"])
    actions = Map.get(row, "actions", [])
    conversions = extract_conversions(actions)
    impressions = parse_integer(row["impressions"])
    clicks = parse_integer(row["clicks"])
    spend = parse_float(row["spend"])
    cpm = parse_float(row["cpm"])
    cpc = parse_float(row["cpc"])
    ctr = parse_float(row["ctr"])
    conversion_rate = calculate_conversion_rate(conversions, impressions)

    metadata = %{
      campaign_name: row["campaign_name"],
      adset_name: row["adset_name"],
      ad_account_id: ad_account_id
    }

    [
      build_metric("ad_performance", "impressions", impressions, recorded_at, metadata),
      build_metric("ad_performance", "clicks", clicks, recorded_at, metadata),
      build_metric("ad_performance", "spend", spend, recorded_at, metadata),
      build_metric("ad_performance", "cpm", cpm, recorded_at, metadata),
      build_metric("ad_performance", "cpc", cpc, recorded_at, metadata),
      build_metric("ad_performance", "ctr", ctr, recorded_at, metadata),
      build_metric("ad_performance", "conversions", conversions, recorded_at, metadata),
      build_metric("ad_performance", "conversion_rate", conversion_rate, recorded_at, metadata)
    ]
  end

  defp build_metric(metric_type, metric_name, value, recorded_at, metadata) do
    %{
      metric_type: metric_type,
      metric_name: metric_name,
      value: value,
      recorded_at: recorded_at,
      metadata: metadata,
      provider: :facebook_ads
    }
  end

  defp extract_conversions(nil), do: 0
  defp extract_conversions([]), do: 0

  defp extract_conversions(actions) when is_list(actions) do
    actions
    |> Enum.filter(fn action -> action["action_type"] in @conversion_action_types end)
    |> Enum.reduce(0, fn action, acc -> acc + parse_integer(action["value"]) end)
  end

  defp calculate_conversion_rate(_conversions, 0), do: 0.0

  defp calculate_conversion_rate(conversions, impressions) when impressions > 0 do
    conversions / impressions * 100.0
  end

  defp parse_integer(nil), do: 0
  defp parse_integer(value) when is_integer(value), do: value

  defp parse_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, _rest} -> int
      :error -> 0
    end
  end

  defp parse_integer(value) when is_float(value), do: trunc(value)
  defp parse_integer(_), do: 0

  defp parse_float(nil), do: 0.0
  defp parse_float(value) when is_float(value), do: value
  defp parse_float(value) when is_integer(value), do: value * 1.0

  defp parse_float(value) when is_binary(value) do
    case Float.parse(value) do
      {float, _rest} -> float
      :error -> 0.0
    end
  end

  defp parse_float(_), do: 0.0

  defp parse_date_start(nil), do: DateTime.utc_now()

  defp parse_date_start(date_string) when is_binary(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
      {:error, _} -> DateTime.utc_now()
    end
  end

  defp parse_date_start(_), do: DateTime.utc_now()
end
