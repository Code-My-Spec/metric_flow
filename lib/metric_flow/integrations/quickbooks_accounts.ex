defmodule MetricFlow.Integrations.QuickBooksAccounts do
  @moduledoc """
  Fetches income accounts from the QuickBooks Chart of Accounts API.

  Queries for accounts with AccountType 'Income' so users can select
  which income account to track credits/debits from for correlation analysis.
  """

  require Logger

  alias MetricFlow.Integrations.Integration

  @base_url Application.compile_env(:metric_flow, :quickbooks_api_url, "https://sandbox-quickbooks.api.intuit.com/v3/company")

  @spec list_income_accounts(Integration.t(), keyword()) ::
          {:ok, list(map())} | {:error, term()}
  def list_income_accounts(%Integration{} = integration, opts \\ []) do
    realm_id = get_in(integration.provider_metadata || %{}, ["realm_id"])

    unless realm_id do
      {:error, :missing_realm_id}
    else
      query = "SELECT * FROM Account WHERE AccountType = 'Income' MAXRESULTS 100"
      url = "#{@base_url}/#{realm_id}/query"

      req_opts =
        [
          method: :get,
          url: url,
          params: [{"query", query}],
          headers: [
            {"authorization", "Bearer #{integration.access_token}"},
            {"accept", "application/json"}
          ]
        ]
        |> maybe_put_plug(opts)

      try do
        response = Req.request!(req_opts)
        handle_response(response)
      rescue
        e ->
          Logger.error("QuickBooks accounts query failed: #{Exception.message(e)}")
          {:error, {:network_error, Exception.message(e)}}
      end
    end
  end

  defp maybe_put_plug(req_opts, opts) do
    case Keyword.get(opts, :http_plug) do
      nil -> req_opts
      plug -> Keyword.put(req_opts, :plug, plug)
    end
  end

  defp handle_response(%Req.Response{status: 200, body: body}) when is_map(body) do
    {:ok, extract_accounts(body)}
  end

  defp handle_response(%Req.Response{status: 200, body: body}) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} -> {:ok, extract_accounts(decoded)}
      _ -> {:error, :malformed_response}
    end
  end

  defp handle_response(%Req.Response{status: 401}), do: {:error, :unauthorized}

  defp handle_response(%Req.Response{status: 403}) do
    Logger.warning("QuickBooks API returned 403")
    {:error, :api_disabled}
  end

  defp handle_response(%Req.Response{status: status, body: body}) do
    Logger.warning("QuickBooks accounts query returned #{status}: #{inspect(body)}")
    {:error, :bad_request}
  end

  defp extract_accounts(%{"QueryResponse" => %{"Account" => accounts}}) when is_list(accounts) do
    Enum.map(accounts, fn acct ->
      %{
        id: to_string(Map.get(acct, "Id", "")),
        name: Map.get(acct, "Name", "Unknown Account"),
        account: Map.get(acct, "FullyQualifiedName", Map.get(acct, "Name", ""))
      }
    end)
  end

  defp extract_accounts(_body), do: []
end
