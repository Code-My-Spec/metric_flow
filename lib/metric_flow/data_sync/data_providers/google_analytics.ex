defmodule MetricFlow.DataSync.DataProviders.GoogleAnalytics do
  @moduledoc """
  Google Analytics data provider implementing the DataProviders.Behaviour contract.

  Fetches website traffic metrics from the Google Analytics Data API (GA4),
  including sessions, pageviews, users, bounce_rate, average_session_duration,
  and new_users. Supports dimension breakdowns by date, source/medium, and
  page path. Transforms GA4 API responses to the unified metric format and
  stores metrics with provider :google_analytics.

  Accepts an `http_plug` option for dependency injection during tests, allowing
  callers to supply a Plug-compatible function instead of making real HTTP calls.
  """

  @behaviour MetricFlow.DataSync.DataProviders.Behaviour

  alias MetricFlow.Integrations.Integration

  @ga4_base_url "https://analyticsdata.googleapis.com/v1beta"

  @metric_names [
    "sessions",
    "screenPageViews",
    "activeUsers",
    "bounceRate",
    "averageSessionDuration",
    "newUsers"
  ]

  # Safe compile-time mapping of the known GA4 dimension name strings to atoms.
  # Using a fixed map avoids calling String.to_atom/1 on external API data,
  # which would risk exhausting the atom table with adversarial input.
  @dimension_name_to_atom %{
    "date" => :date,
    "sessionSource" => :sessionSource,
    "sessionMedium" => :sessionMedium,
    "pagePath" => :pagePath
  }

  # Maximum number of pages to fetch in a single call to prevent runaway pagination.
  @max_pages 100

  # ---------------------------------------------------------------------------
  # Behaviour callbacks
  # ---------------------------------------------------------------------------

  @doc """
  Fetches GA4 metrics for an integration using OAuth tokens.

  Accepts the following options:
  - `:property_id` - GA4 property ID (e.g. "properties/123456789"). Falls back
    to integration.provider_metadata["property_id"] when not supplied.
  - `:date_range` - A `{%Date{}, %Date{}}` tuple for `{start_date, end_date}`.
    Defaults to the last 30 days.
  - `:breakdown` - Dimension grouping atom. `:source` adds sessionSource and
    sessionMedium; `:page` adds pagePath. Date dimension is always included.
  - `:http_plug` - A Plug-compatible function used instead of Finch for HTTP
    transport. Intended for test use only.
  """
  @spec fetch_metrics(Integration.t(), keyword()) :: {:ok, list(map())} | {:error, term()}
  def fetch_metrics(%Integration{} = integration, opts) do
    with :ok <- check_not_expired(integration),
         {:ok, property_id} <- resolve_property_id(integration, opts) do
      fetch_all_pages(integration, property_id, opts, nil, [], @max_pages)
    end
  end

  @doc """
  Returns the provider atom identifier for this data provider.
  """
  @spec provider() :: :google_analytics
  def provider, do: :google_analytics

  @doc """
  Returns the OAuth scopes required for fetching Google Analytics metrics.
  """
  @spec required_scopes() :: list(String.t())
  def required_scopes do
    ["https://www.googleapis.com/auth/analytics.readonly"]
  end

  # ---------------------------------------------------------------------------
  # Private helpers — guards & config resolution
  # ---------------------------------------------------------------------------

  defp check_not_expired(%Integration{} = integration) do
    if Integration.expired?(integration) do
      {:error, :unauthorized}
    else
      :ok
    end
  end

  defp resolve_property_id(%Integration{provider_metadata: metadata}, opts) do
    case Keyword.get(opts, :property_id) || Map.get(metadata || %{}, "property_id") do
      nil -> {:error, :missing_property_id}
      "" -> {:error, :missing_property_id}
      id -> {:ok, id}
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers — pagination
  # ---------------------------------------------------------------------------

  defp fetch_all_pages(_integration, _property_id, _opts, _page_token, accumulated, 0) do
    {:ok, accumulated}
  end

  defp fetch_all_pages(integration, property_id, opts, page_token, accumulated, pages_remaining) do
    case execute_request(integration, property_id, opts, page_token) do
      {:ok, %{"rows" => rows, "nextPageToken" => next_token}} when is_list(rows) ->
        metrics = transform_rows(rows, opts)

        fetch_all_pages(
          integration,
          property_id,
          opts,
          next_token,
          accumulated ++ metrics,
          pages_remaining - 1
        )

      {:ok, %{"rows" => rows}} when is_list(rows) ->
        metrics = transform_rows(rows, opts)
        {:ok, accumulated ++ metrics}

      {:ok, _body} ->
        {:ok, accumulated}

      {:error, _} = err ->
        err
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers — HTTP
  # ---------------------------------------------------------------------------

  defp execute_request(integration, property_id, opts, page_token) do
    url = "#{@ga4_base_url}/#{property_id}:runReport"
    body = build_request_body(opts, page_token)
    headers = [{"authorization", "Bearer #{integration.access_token}"}]

    req_opts =
      [
        method: :post,
        url: url,
        headers: headers,
        json: body
      ]
      |> maybe_put_plug(opts)

    try do
      response = Req.request!(req_opts)
      handle_response(response)
    rescue
      e ->
        {:error, {:network_error, Exception.message(e)}}
    end
  end

  defp maybe_put_plug(req_opts, opts) do
    case Keyword.get(opts, :http_plug) do
      nil -> req_opts
      plug -> Keyword.put(req_opts, :plug, plug)
    end
  end

  defp handle_response(%Req.Response{status: 200, body: body}) when is_map(body) do
    {:ok, body}
  end

  defp handle_response(%Req.Response{status: 200, body: body}) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} -> {:ok, decoded}
      {:error, _} -> {:error, :malformed_response}
    end
  end

  defp handle_response(%Req.Response{status: 401}), do: {:error, :unauthorized}
  defp handle_response(%Req.Response{status: 403}), do: {:error, :insufficient_permissions}
  defp handle_response(%Req.Response{status: 404}), do: {:error, :property_not_found}
  defp handle_response(%Req.Response{status: _}), do: {:error, :bad_request}

  # ---------------------------------------------------------------------------
  # Private helpers — request building
  # ---------------------------------------------------------------------------

  defp build_request_body(opts, page_token) do
    {start_date, end_date} = resolve_date_range(opts)

    body = %{
      "dateRanges" => [
        %{
          "startDate" => Date.to_iso8601(start_date),
          "endDate" => Date.to_iso8601(end_date)
        }
      ],
      "metrics" => Enum.map(@metric_names, &%{"name" => &1}),
      "dimensions" => build_dimensions(opts)
    }

    if page_token do
      Map.put(body, "pageToken", page_token)
    else
      body
    end
  end

  defp resolve_date_range(opts) do
    case Keyword.get(opts, :date_range) do
      {start_date, end_date} ->
        {start_date, end_date}

      nil ->
        today = Date.utc_today()
        {Date.add(today, -30), today}
    end
  end

  defp build_dimensions(opts) do
    base = [%{"name" => "date"}]

    case Keyword.get(opts, :breakdown) do
      :source ->
        base ++ [%{"name" => "sessionSource"}, %{"name" => "sessionMedium"}]

      :page ->
        base ++ [%{"name" => "pagePath"}]

      _ ->
        base
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers — response transformation
  # ---------------------------------------------------------------------------

  defp transform_rows(rows, opts) do
    dimension_names = build_dimension_names(opts)

    Enum.flat_map(rows, fn row ->
      dimension_values = extract_dimension_values(row)
      metric_values = extract_metric_values(row)

      recorded_at = parse_recorded_at(dimension_values, dimension_names)
      dimensions = build_dimensions_map(dimension_values, dimension_names)

      Enum.zip(@metric_names, metric_values)
      |> Enum.map(fn {metric_name, raw_value} ->
        %{
          metric_type: "traffic",
          metric_name: metric_name,
          value: parse_metric_value(metric_name, raw_value),
          recorded_at: recorded_at,
          dimensions: dimensions,
          provider: :google_analytics
        }
      end)
    end)
  end

  defp build_dimension_names(opts) do
    base = ["date"]

    case Keyword.get(opts, :breakdown) do
      :source -> base ++ ["sessionSource", "sessionMedium"]
      :page -> base ++ ["pagePath"]
      _ -> base
    end
  end

  defp extract_dimension_values(%{"dimensionValues" => values}) when is_list(values) do
    Enum.map(values, & &1["value"])
  end

  defp extract_dimension_values(_), do: []

  defp extract_metric_values(%{"metricValues" => values}) when is_list(values) do
    Enum.map(values, & &1["value"])
  end

  defp extract_metric_values(_), do: []

  defp parse_recorded_at(dimension_values, dimension_names) do
    date_index = Enum.find_index(dimension_names, &(&1 == "date"))

    raw_date =
      if date_index do
        Enum.at(dimension_values, date_index)
      end

    case raw_date do
      <<year::binary-size(4), month::binary-size(2), day::binary-size(2)>> ->
        case Date.from_iso8601("#{year}-#{month}-#{day}") do
          {:ok, date} ->
            DateTime.new!(date, ~T[00:00:00], "Etc/UTC")

          _ ->
            DateTime.utc_now()
        end

      _ ->
        DateTime.utc_now()
    end
  end

  defp build_dimensions_map(dimension_values, dimension_names) do
    dimension_names
    |> Enum.zip(dimension_values)
    |> Enum.into(%{}, fn {name, value} ->
      {Map.fetch!(@dimension_name_to_atom, name), value}
    end)
  end

  defp parse_metric_value("bounceRate", raw) do
    case Float.parse(raw) do
      {val, _} -> val
      :error -> 0.0
    end
  end

  defp parse_metric_value("averageSessionDuration", raw) do
    case Float.parse(raw) do
      {val, _} -> val
      :error -> 0.0
    end
  end

  defp parse_metric_value(_name, raw) do
    case Integer.parse(raw) do
      {val, ""} ->
        val

      _ ->
        case Float.parse(raw) do
          {val, _} -> val
          :error -> 0
        end
    end
  end
end
