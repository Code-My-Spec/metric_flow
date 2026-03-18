defmodule MetricFlow.DataSync.DataProviders.GoogleSearchConsole do
  @moduledoc """
  Google Search Console data provider implementing the DataProviders.Behaviour contract.

  Fetches search performance metrics from the Search Console API (Webmasters v3),
  including clicks, impressions, CTR, and average position. Queries are scoped
  to a verified site URL and segmented by date dimension only.

  Accepts an `http_plug` option for dependency injection during tests.
  """

  @behaviour MetricFlow.DataSync.DataProviders.Behaviour

  require Logger

  alias MetricFlow.Integrations.Integration

  @base_url "https://www.googleapis.com/webmasters/v3/sites"

  @metric_names ["clicks", "impressions", "ctr", "position"]

  @max_pages 10
  @rows_per_page 25_000

  # ---------------------------------------------------------------------------
  # Behaviour callbacks
  # ---------------------------------------------------------------------------

  @doc """
  Fetches Search Console metrics for an integration.

  Options:
  - `:site_url` - The verified site URL. Falls back to
    `integration.provider_metadata["site_url"]`.
  - `:date_range` - `{start_date, end_date}` tuple. Defaults to last 30 days.
  - `:http_plug` - Plug function for test injection.
  """
  @spec fetch_metrics(Integration.t(), keyword()) :: {:ok, list(map())} | {:error, term()}
  def fetch_metrics(%Integration{} = integration, opts \\ []) do
    with :ok <- check_not_expired(integration),
         {:ok, site_url} <- resolve_site_url(integration, opts) do
      {start_date, end_date} = resolve_date_range(opts)
      fetch_all_rows(integration, site_url, start_date, end_date, opts, 0, [], @max_pages)
    end
  end

  @spec provider() :: :google_search_console
  def provider, do: :google_search_console

  @spec required_scopes() :: list(String.t())
  def required_scopes do
    ["https://www.googleapis.com/auth/webmasters.readonly"]
  end

  # ---------------------------------------------------------------------------
  # Private — config resolution
  # ---------------------------------------------------------------------------

  defp check_not_expired(%Integration{} = integration) do
    if Integration.expired?(integration), do: {:error, :unauthorized}, else: :ok
  end

  defp resolve_site_url(%Integration{provider_metadata: meta}, opts) do
    case Keyword.get(opts, :site_url) || Map.get(meta || %{}, "site_url") do
      nil -> {:error, :missing_site_url}
      "" -> {:error, :missing_site_url}
      url -> {:ok, url}
    end
  end

  defp resolve_date_range(opts) do
    case Keyword.get(opts, :date_range) do
      {start_date, end_date} -> {start_date, end_date}
      nil ->
        today = Date.utc_today()
        {Date.add(today, -30), Date.add(today, -1)}
    end
  end

  # ---------------------------------------------------------------------------
  # Private — pagination
  # ---------------------------------------------------------------------------

  defp fetch_all_rows(_integration, _site_url, _start, _end, _opts, _offset, accumulated, 0) do
    {:ok, accumulated}
  end

  defp fetch_all_rows(integration, site_url, start_date, end_date, opts, offset, accumulated, pages_remaining) do
    case execute_request(integration, site_url, start_date, end_date, opts, offset) do
      {:ok, rows} when is_list(rows) and length(rows) == @rows_per_page ->
        metrics = transform_rows(rows)
        fetch_all_rows(
          integration, site_url, start_date, end_date, opts,
          offset + @rows_per_page, accumulated ++ metrics, pages_remaining - 1
        )

      {:ok, rows} when is_list(rows) ->
        metrics = transform_rows(rows)
        {:ok, accumulated ++ metrics}

      {:ok, _} ->
        {:ok, accumulated}

      {:error, _} = err ->
        err
    end
  end

  # ---------------------------------------------------------------------------
  # Private — HTTP
  # ---------------------------------------------------------------------------

  defp execute_request(integration, site_url, start_date, end_date, opts, offset) do
    encoded_site = URI.encode_www_form(site_url)
    url = "#{@base_url}/#{encoded_site}/searchAnalytics/query"

    body = %{
      "startDate" => Date.to_iso8601(start_date),
      "endDate" => Date.to_iso8601(end_date),
      "dimensions" => ["date"],
      "rowLimit" => @rows_per_page,
      "startRow" => offset
    }

    headers = [{"authorization", "Bearer #{integration.access_token}"}]

    req_opts =
      [method: :post, url: url, headers: headers, json: body]
      |> maybe_put_plug(opts)

    try do
      response = Req.request!(req_opts)
      handle_response(response)
    rescue
      e ->
        Logger.error("Search Console API request failed: #{Exception.message(e)}")
        {:error, {:network_error, Exception.message(e)}}
    end
  end

  defp maybe_put_plug(req_opts, opts) do
    case Keyword.get(opts, :http_plug) do
      nil -> req_opts
      plug -> Keyword.put(req_opts, :plug, plug)
    end
  end

  defp handle_response(%Req.Response{status: 200, body: %{"rows" => rows}}) when is_list(rows) do
    {:ok, rows}
  end

  defp handle_response(%Req.Response{status: 200, body: body}) when is_map(body) do
    # No rows key means no data for this date range
    {:ok, []}
  end

  defp handle_response(%Req.Response{status: 200, body: body}) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, %{"rows" => rows}} -> {:ok, rows}
      {:ok, _} -> {:ok, []}
      {:error, _} -> {:error, :malformed_response}
    end
  end

  defp handle_response(%Req.Response{status: 401}), do: {:error, :unauthorized}
  defp handle_response(%Req.Response{status: 403}), do: {:error, :insufficient_permissions}
  defp handle_response(%Req.Response{status: 404}), do: {:error, :site_not_found}

  defp handle_response(%Req.Response{status: status, body: body}) do
    Logger.warning("Search Console API returned #{status}: #{inspect(body)}")
    {:error, :bad_request}
  end

  # ---------------------------------------------------------------------------
  # Private — response transformation
  # ---------------------------------------------------------------------------

  defp transform_rows(rows) do
    Enum.flat_map(rows, fn row ->
      date_str = row |> Map.get("keys", []) |> List.first()
      recorded_at = parse_date(date_str)

      @metric_names
      |> Enum.filter(fn name -> Map.has_key?(row, name) end)
      |> Enum.map(fn metric_name ->
        %{
          metric_type: "search",
          metric_name: metric_name,
          value: parse_value(metric_name, Map.get(row, metric_name, 0)),
          recorded_at: recorded_at,
          dimensions: %{date: date_str},
          provider: :google_search_console
        }
      end)
    end)
  end

  defp parse_date(nil), do: DateTime.utc_now()

  defp parse_date(date_str) when is_binary(date_str) do
    case Date.from_iso8601(date_str) do
      {:ok, date} -> DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
      _ -> DateTime.utc_now()
    end
  end

  defp parse_value("ctr", val) when is_number(val), do: Float.round(val * 1.0, 4)
  defp parse_value("position", val) when is_number(val), do: Float.round(val * 1.0, 2)
  defp parse_value(_name, val) when is_integer(val), do: val
  defp parse_value(_name, val) when is_float(val), do: round(val)
  defp parse_value(_name, _val), do: 0
end
