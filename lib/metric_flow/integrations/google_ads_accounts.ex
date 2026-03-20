defmodule MetricFlow.Integrations.GoogleAdsAccounts do
  @moduledoc """
  Fetches accessible Google Ads customer accounts for a Google Ads OAuth integration.

  Uses the Google Ads API `customers:listAccessibleCustomers` endpoint to discover
  which customer accounts the authenticated user can access, then queries each
  customer's descriptive name via `googleAds:searchStream`.

  Accepts an `:http_plug` option for dependency injection during tests.
  """

  require Logger

  alias MetricFlow.Integrations.Integration

  @list_url "https://googleads.googleapis.com/v23/customers:listAccessibleCustomers"
  @search_url "https://googleads.googleapis.com/v23/customers"

  @doc """
  Lists Google Ads customer accounts accessible to the integration's OAuth token.

  Returns `{:ok, customers}` where each customer is a map with `:id`, `:name`,
  and `:account` keys. Fetches descriptive names for each accessible customer.
  """
  @spec list_customers(Integration.t(), keyword()) ::
          {:ok, list(map())} | {:error, term()}
  def list_customers(%Integration{} = integration, opts \\ []) do
    developer_token = Application.get_env(:metric_flow, :google_ads_developer_token)

    headers = build_headers(integration.access_token, developer_token)

    with {:ok, customer_ids} <- fetch_accessible_customers(headers, opts) do
      customers = fetch_customer_names(customer_ids, headers, opts)
      {:ok, customers}
    end
  end

  # Step 1: Get the list of accessible customer IDs
  defp fetch_accessible_customers(headers, opts) do
    req_opts =
      [method: :get, url: @list_url, headers: headers]
      |> maybe_put_plug(opts)

    try do
      case Req.request!(req_opts) do
        %Req.Response{status: 200, body: %{"resourceNames" => names}} when is_list(names) ->
          ids = Enum.map(names, &String.replace(&1, "customers/", ""))
          {:ok, ids}

        %Req.Response{status: 200, body: body} when is_binary(body) ->
          case Jason.decode(body) do
            {:ok, %{"resourceNames" => names}} ->
              {:ok, Enum.map(names, &String.replace(&1, "customers/", ""))}
            _ ->
              {:ok, []}
          end

        %Req.Response{status: 401} -> {:error, :unauthorized}
        %Req.Response{status: 403} ->
          Logger.warning("Google Ads API returned 403 — insufficient permissions")
          {:error, :api_disabled}
        %Req.Response{status: status} ->
          Logger.warning("Google Ads listAccessibleCustomers returned status #{status}")
          {:error, :bad_request}
      end
    rescue
      e ->
        Logger.error("Google Ads listAccessibleCustomers failed: #{Exception.message(e)}")
        {:error, {:network_error, Exception.message(e)}}
    end
  end

  # Step 2: For each customer ID, query their descriptive name and manager status.
  # Manager (MCC) accounts are filtered out — the Google Ads API does not return
  # metrics for manager accounts.
  defp fetch_customer_names(customer_ids, headers, opts) do
    customer_ids
    |> Enum.map(fn customer_id ->
      {name, manager?} = fetch_single_customer_info(customer_id, headers, opts)
      %{id: customer_id, name: name, account: "Google Ads", manager: manager?}
    end)
    |> Enum.reject(& &1.manager)
    |> Enum.map(&Map.delete(&1, :manager))
  end

  defp fetch_single_customer_info(customer_id, headers, opts) do
    url = "#{@search_url}/#{customer_id}/googleAds:searchStream"
    body = Jason.encode!(%{"query" => "SELECT customer.descriptive_name, customer.id, customer.manager FROM customer LIMIT 1"})

    req_opts =
      [method: :post, url: url, headers: headers ++ [{"content-type", "application/json"}], body: body]
      |> maybe_put_plug(opts)

    try do
      case Req.request!(req_opts) do
        %Req.Response{status: 200, body: body} ->
          extract_customer_info(body, customer_id)

        _ ->
          {"Account #{customer_id}", false}
      end
    rescue
      _ -> {"Account #{customer_id}", false}
    end
  end

  defp extract_customer_info(body, customer_id) when is_list(body) do
    # searchStream returns an array of result batches
    body
    |> Enum.flat_map(fn batch -> Map.get(batch, "results", []) end)
    |> List.first()
    |> case do
      %{"customer" => customer} ->
        name = case customer["descriptiveName"] do
          n when is_binary(n) and n != "" -> n
          _ -> "Account #{customer_id}"
        end
        {name, customer["manager"] == true}

      _ ->
        {"Account #{customer_id}", false}
    end
  end

  defp extract_customer_info(body, customer_id) when is_map(body) do
    # Sometimes Req auto-decodes a single-element array
    customer = get_in(body, ["results", Access.at(0), "customer"]) || %{}
    name = case customer["descriptiveName"] do
      n when is_binary(n) and n != "" -> n
      _ -> "Account #{customer_id}"
    end
    {name, customer["manager"] == true}
  end

  defp extract_customer_info(_body, customer_id), do: {"Account #{customer_id}", false}

  # Helpers

  defp build_headers(access_token, developer_token) do
    [
      {"authorization", "Bearer #{access_token}"},
      {"developer-token", developer_token || ""}
    ]
  end

  defp maybe_put_plug(req_opts, opts) do
    case Keyword.get(opts, :http_plug) do
      nil -> req_opts
      plug -> Keyword.put(req_opts, :plug, plug)
    end
  end
end
