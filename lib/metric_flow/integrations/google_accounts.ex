defmodule MetricFlow.Integrations.GoogleAccounts do
  @moduledoc """
  Fetches available GA4 properties for a Google OAuth integration.

  Uses the Google Analytics Admin API (`analyticsadmin.googleapis.com`) to list
  account summaries and their GA4 properties. Falls back to allowing manual
  property ID entry when the API is unavailable (403/SERVICE_DISABLED).

  Accepts an `:http_plug` option for dependency injection during tests.
  """

  require Logger

  alias MetricFlow.Integrations.Integration

  @admin_api_url "https://analyticsadmin.googleapis.com/v1beta/accountSummaries"

  @doc """
  Lists GA4 properties accessible to the integration's OAuth token.

  Returns `{:ok, properties}` where each property is a map with `:id`, `:name`,
  and `:account` keys. Returns `{:error, :api_disabled}` when the Admin API is
  not enabled, or `{:error, reason}` for other failures.

  ## Options

    * `:http_plug` - A Plug-compatible function for test injection.
  """
  @spec list_ga4_properties(Integration.t(), keyword()) ::
          {:ok, list(map())} | {:error, term()}
  def list_ga4_properties(%Integration{} = integration, opts \\ []) do
    headers = [{"authorization", "Bearer #{integration.access_token}"}]

    req_opts =
      [method: :get, url: @admin_api_url, headers: headers]
      |> maybe_put_plug(opts)

    try do
      response = Req.request!(req_opts)
      handle_response(response)
    rescue
      e ->
        Logger.error("Google Accounts API request failed: #{Exception.message(e)}")
        {:error, {:network_error, Exception.message(e)}}
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp maybe_put_plug(req_opts, opts) do
    case Keyword.get(opts, :http_plug) do
      nil -> req_opts
      plug -> Keyword.put(req_opts, :plug, plug)
    end
  end

  defp handle_response(%Req.Response{status: 200, body: body}) when is_map(body) do
    properties = extract_properties(body)
    {:ok, properties}
  end

  defp handle_response(%Req.Response{status: 200, body: body}) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} -> {:ok, extract_properties(decoded)}
      {:error, _} -> {:error, :malformed_response}
    end
  end

  defp handle_response(%Req.Response{status: 401}), do: {:error, :unauthorized}

  defp handle_response(%Req.Response{status: 403}) do
    Logger.warning("Google Analytics Admin API returned 403 — API may not be enabled in GCP project")
    {:error, :api_disabled}
  end

  defp handle_response(%Req.Response{status: status}) do
    Logger.warning("Google Analytics Admin API returned unexpected status: #{status}")
    {:error, :bad_request}
  end

  defp extract_properties(%{"accountSummaries" => summaries}) when is_list(summaries) do
    Enum.flat_map(summaries, fn summary ->
      account_name = Map.get(summary, "displayName", "Unknown Account")

      summary
      |> Map.get("propertySummaries", [])
      |> Enum.map(fn prop ->
        %{
          id: Map.get(prop, "property"),
          name: Map.get(prop, "displayName", "Unnamed Property"),
          account: account_name
        }
      end)
    end)
  end

  defp extract_properties(_body), do: []
end
