defmodule MetricFlow.Integrations.GoogleSearchConsoleSites do
  @moduledoc """
  Fetches verified sites from the Google Search Console API.

  Uses the Webmasters API v3 sites endpoint to list all sites
  the authenticated user has access to in Search Console.
  """

  require Logger

  alias MetricFlow.Integrations.Integration

  @api_url "https://www.googleapis.com/webmasters/v3/sites"

  @spec list_sites(Integration.t(), keyword()) ::
          {:ok, list(map())} | {:error, term()}
  def list_sites(%Integration{} = integration, opts \\ []) do
    headers = [{"authorization", "Bearer #{integration.access_token}"}]

    req_opts =
      [method: :get, url: @api_url, headers: headers]
      |> maybe_put_plug(opts)

    try do
      response = Req.request!(req_opts)
      handle_response(response)
    rescue
      e ->
        Logger.error("Google Search Console sites API failed: #{Exception.message(e)}")
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
    {:ok, extract_sites(body)}
  end

  defp handle_response(%Req.Response{status: 200, body: body}) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} -> {:ok, extract_sites(decoded)}
      {:error, _} -> {:error, :malformed_response}
    end
  end

  defp handle_response(%Req.Response{status: 401}), do: {:error, :unauthorized}

  defp handle_response(%Req.Response{status: 403}) do
    Logger.warning("Google Search Console API returned 403 — API may not be enabled or insufficient permissions")
    {:error, :api_disabled}
  end

  defp handle_response(%Req.Response{status: status}) do
    Logger.warning("Google Search Console sites API returned unexpected status: #{status}")
    {:error, :bad_request}
  end

  defp extract_sites(%{"siteEntry" => entries}) when is_list(entries) do
    Enum.map(entries, fn entry ->
      site_url = Map.get(entry, "siteUrl", "")
      display_name = site_url |> URI.parse() |> Map.get(:host, site_url) || site_url

      %{
        id: site_url,
        name: display_name,
        account: "Google Search Console"
      }
    end)
  end

  defp extract_sites(_body), do: []
end
