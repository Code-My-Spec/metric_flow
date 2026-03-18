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
    login_customer_id = Application.get_env(:metric_flow, :google_ads_login_customer_id)

    headers = build_headers(integration.access_token, developer_token, login_customer_id)

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

  # Step 2: For each customer ID, query their descriptive name
  defp fetch_customer_names(customer_ids, headers, opts) do
    Enum.map(customer_ids, fn customer_id ->
      name = fetch_single_customer_name(customer_id, headers, opts)
      %{id: customer_id, name: name, account: "Google Ads"}
    end)
  end

  defp fetch_single_customer_name(customer_id, headers, opts) do
    url = "#{@search_url}/#{customer_id}/googleAds:searchStream"
    body = Jason.encode!(%{"query" => "SELECT customer.descriptive_name, customer.id FROM customer LIMIT 1"})

    req_opts =
      [method: :post, url: url, headers: headers ++ [{"content-type", "application/json"}], body: body]
      |> maybe_put_plug(opts)

    try do
      case Req.request!(req_opts) do
        %Req.Response{status: 200, body: body} ->
          extract_customer_name(body, customer_id)

        _ ->
          "Account #{customer_id}"
      end
    rescue
      _ -> "Account #{customer_id}"
    end
  end

  defp extract_customer_name(body, customer_id) when is_list(body) do
    # searchStream returns an array of result batches
    body
    |> Enum.flat_map(fn batch -> Map.get(batch, "results", []) end)
    |> List.first()
    |> case do
      %{"customer" => %{"descriptiveName" => name}} when is_binary(name) and name != "" -> name
      _ -> "Account #{customer_id}"
    end
  end

  defp extract_customer_name(body, customer_id) when is_map(body) do
    # Sometimes Req auto-decodes a single-element array
    case get_in(body, ["results", Access.at(0), "customer", "descriptiveName"]) do
      name when is_binary(name) and name != "" -> name
      _ -> "Account #{customer_id}"
    end
  end

  defp extract_customer_name(_body, customer_id), do: "Account #{customer_id}"

  # Helpers

  defp build_headers(access_token, developer_token, login_customer_id) do
    [
      {"authorization", "Bearer #{access_token}"},
      {"developer-token", developer_token || ""}
    ]
    |> maybe_add_login_customer_id(login_customer_id)
  end

  defp maybe_add_login_customer_id(headers, nil), do: headers
  defp maybe_add_login_customer_id(headers, ""), do: headers
  defp maybe_add_login_customer_id(headers, id), do: headers ++ [{"login-customer-id", id}]

  defp maybe_put_plug(req_opts, opts) do
    case Keyword.get(opts, :http_plug) do
      nil -> req_opts
      plug -> Keyword.put(req_opts, :plug, plug)
    end
  end
end
