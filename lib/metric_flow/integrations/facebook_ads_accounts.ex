defmodule MetricFlow.Integrations.FacebookAdsAccounts do
  @moduledoc """
  Fetches accessible Facebook Ad accounts for a Facebook Ads OAuth integration.

  Uses the Facebook Graph API `me/adaccounts` endpoint to list ad accounts
  the authenticated user can access.
  """

  require Logger

  alias MetricFlow.Integrations.Integration

  @api_url "https://graph.facebook.com/v22.0/me/adaccounts"

  @spec list_accounts(Integration.t(), keyword()) ::
          {:ok, list(map())} | {:error, term()}
  def list_accounts(%Integration{} = integration, opts \\ []) do
    params = [
      {"access_token", integration.access_token},
      {"fields", "name,account_id,account_status"}
    ]

    req_opts =
      [method: :get, url: @api_url, params: params]
      |> maybe_put_plug(opts)

    try do
      response = Req.request!(req_opts)
      handle_response(response)
    rescue
      e ->
        Logger.error("Facebook Ads accounts API failed: #{Exception.message(e)}")
        {:error, {:network_error, Exception.message(e)}}
    end
  end

  defp maybe_put_plug(req_opts, opts) do
    case Keyword.get(opts, :http_plug) do
      nil -> req_opts
      plug -> Keyword.put(req_opts, :plug, plug)
    end
  end

  defp handle_response(%Req.Response{status: 200, body: %{"data" => accounts}}) when is_list(accounts) do
    {:ok, extract_accounts(accounts)}
  end

  defp handle_response(%Req.Response{status: 200, body: body}) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, %{"data" => accounts}} -> {:ok, extract_accounts(accounts)}
      _ -> {:ok, []}
    end
  end

  defp handle_response(%Req.Response{status: 200, body: _}), do: {:ok, []}

  defp handle_response(%Req.Response{status: status}) when status in [400, 401] do
    {:error, :unauthorized}
  end

  defp handle_response(%Req.Response{status: 403}) do
    Logger.warning("Facebook Ads API returned 403 — insufficient permissions")
    {:error, :api_disabled}
  end

  defp handle_response(%Req.Response{status: status}) do
    Logger.warning("Facebook Ads accounts API returned status #{status}")
    {:error, :bad_request}
  end

  defp extract_accounts(accounts) do
    accounts
    |> Enum.filter(fn acct -> Map.get(acct, "account_status") == 1 end)
    |> Enum.map(fn acct ->
      account_id = Map.get(acct, "account_id", "")

      %{
        id: account_id,
        name: Map.get(acct, "name", "Ad Account #{account_id}"),
        account: "Facebook Ads"
      }
    end)
  end
end
