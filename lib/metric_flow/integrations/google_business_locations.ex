defmodule MetricFlow.Integrations.GoogleBusinessLocations do
  @moduledoc """
  Fetches locations across all Google Business Profile accounts.

  Uses the My Business Business Information API v1 to list locations
  for each configured account ID. Handles pagination via `nextPageToken`
  and merges results into a flat list.

  Accepts an `:http_plug` option for dependency injection during tests.
  """

  require Logger

  alias MetricFlow.Integrations.Integration

  @api_base "https://mybusinessbusinessinformation.googleapis.com/v1"
  @accounts_api_base "https://mybusinessaccountmanagement.googleapis.com/v1"

  @doc """
  Lists all locations across all configured GBP account IDs.

  Reads `google_business_account_ids` from the integration's `provider_metadata`
  and fetches locations for each account, handling pagination automatically.

  Returns `{:ok, locations}` where each location is a map with `:id`, `:name`,
  `:account`, `:store_code`, `:address`, `:website`, `:category`, and `:hours`
  keys.
  """
  @spec list_locations(Integration.t(), keyword()) ::
          {:ok, list(map())} | {:error, term()}
  def list_locations(%Integration{} = integration, opts \\ []) do
    account_ids =
      get_in(integration.provider_metadata || %{}, ["google_business_account_ids"]) || []

    case account_ids do
      [] ->
        # No account IDs stored — fetch them from the Account Management API
        case fetch_accounts(integration, opts) do
          {:ok, []} -> {:error, :no_accounts_configured}
          {:ok, fetched_ids} -> collect_locations(integration, fetched_ids, opts)
          {:error, reason} -> {:error, reason}
        end

      ids ->
        collect_locations(integration, ids, opts)
    end
  end

  @doc """
  Fetches the user's GBP account IDs from the Account Management API.

  Returns `{:ok, ["accounts/123", ...]}` on success.
  """
  @spec fetch_accounts(Integration.t(), keyword()) :: {:ok, list(String.t())} | {:error, term()}
  def fetch_accounts(%Integration{} = integration, opts \\ []) do
    with {:ok, raw_accounts} <- fetch_raw_accounts(integration, opts) do
      {:ok, Enum.map(raw_accounts, &Map.get(&1, "name"))}
    end
  end

  @doc """
  Lists the user's GBP accounts with both their ID and display name.

  Returns `{:ok, [%{id: "accounts/123", name: "My Business"}, ...]}` on
  success -- this is what a user actually picks from when authorizing which
  GMB accounts to grant MetricFlow access to, distinct from `list_locations/2`
  which lists individual locations *within* already-authorized accounts.
  """
  @spec list_accounts(Integration.t(), keyword()) :: {:ok, list(map())} | {:error, term()}
  def list_accounts(%Integration{} = integration, opts \\ []) do
    with {:ok, raw_accounts} <- fetch_raw_accounts(integration, opts) do
      accounts =
        Enum.map(raw_accounts, fn account ->
          id = Map.get(account, "name")
          %{id: id, name: Map.get(account, "accountName", id)}
        end)

      {:ok, accounts}
    end
  end

  defp fetch_raw_accounts(%Integration{} = integration, opts) do
    url = "#{@accounts_api_base}/accounts"
    headers = [{"authorization", "Bearer #{integration.access_token}"}]

    req_opts =
      [method: :get, url: url, headers: headers]
      |> maybe_put_plug(opts)

    try do
      response = Req.request!(req_opts)

      case response do
        %Req.Response{status: 200, body: %{"accounts" => accounts}} when is_list(accounts) ->
          {:ok, accounts}

        %Req.Response{status: 200, body: _} ->
          {:ok, []}

        %Req.Response{status: 401} ->
          {:error, :unauthorized}

        %Req.Response{status: 403} ->
          Logger.warning("GBP Account Management API returned 403 — API may not be enabled")
          {:error, :api_disabled}

        %Req.Response{status: status} ->
          Logger.warning("GBP Account Management API returned unexpected status: #{status}")
          {:error, :bad_request}
      end
    rescue
      # A body that arrives with `content-type: application/json` and is not JSON
      # is decoded by Req's own `decode_body` step, which raises before
      # `handle_response/1` ever sees it — so the generic clause below reported a
      # malformed payload as a network failure. Same clause, same reason, as
      # `DataSync.DataProviders.FacebookAds`.
      _e in Jason.DecodeError ->
        {:error, :malformed_response}

      e ->
        Logger.error("GBP Account Management API request failed: #{Exception.message(e)}")
        {:error, {:network_error, Exception.message(e)}}
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  # A 401 or 403 is about the credential, not about one account — every other
  # account in the list is going to answer the same way — so it is returned.
  # The spec says so outright: "On 401, return {:error, :unauthorized}", "On 403,
  # return {:error, :api_disabled}". The version this replaces turned every error
  # into an empty list, so an expired token arrived as `{:ok, []}` and read as
  # "this account has no locations", which is the one answer a sync must not
  # accept quietly.
  #
  # Anything genuinely per-account still degrades to a skip, because that is what
  # the multi-account story wants: one unreachable account must not hide the rest.
  defp collect_locations(integration, account_ids, opts) do
    Enum.reduce_while(account_ids, {:ok, []}, fn account_id, {:ok, acc} ->
      case fetch_locations_for_account(integration, account_id, opts) do
        {:ok, locations} ->
          {:cont, {:ok, acc ++ locations}}

        {:error, reason} when reason in [:unauthorized, :api_disabled] ->
          {:halt, {:error, reason}}

        {:error, reason} ->
          Logger.warning("Failed to fetch locations for #{account_id}: #{inspect(reason)}")
          {:cont, {:ok, acc}}
      end
    end)
  end

  defp fetch_locations_for_account(integration, account_id, opts) do
    fetch_all_pages(integration, account_id, nil, [], opts)
  end

  defp fetch_all_pages(integration, account_id, page_token, acc, opts) do
    url = build_url(account_id, page_token)
    headers = [{"authorization", "Bearer #{integration.access_token}"}]

    req_opts =
      [method: :get, url: url, headers: headers]
      |> maybe_put_plug(opts)

    try do
      response = Req.request!(req_opts)
      handle_response(response, integration, account_id, acc, opts)
    rescue
      # A body that arrives with `content-type: application/json` and is not JSON
      # is decoded by Req's own `decode_body` step, which raises before
      # `handle_response/1` ever sees it — so the generic clause below reported a
      # malformed payload as a network failure. Same clause, same reason, as
      # `DataSync.DataProviders.FacebookAds`.
      _e in Jason.DecodeError ->
        {:error, :malformed_response}

      e ->
        Logger.error("GBP Locations API request failed: #{Exception.message(e)}")
        {:error, {:network_error, Exception.message(e)}}
    end
  end

  defp build_url(account_id, nil) do
    # account_id is like "accounts/123"
    "#{@api_base}/#{account_id}/locations?readMask=name,title,storeCode,storefrontAddress,websiteUri,regularHours,primaryCategory"
  end

  defp build_url(account_id, page_token) do
    build_url(account_id, nil) <> "&pageToken=#{page_token}"
  end

  defp handle_response(%Req.Response{status: 200, body: body}, integration, account_id, acc, opts)
       when is_map(body) do
    locations = extract_locations(body, account_id)
    all = acc ++ locations

    case Map.get(body, "nextPageToken") do
      nil -> {:ok, all}
      token -> fetch_all_pages(integration, account_id, token, all, opts)
    end
  end

  defp handle_response(%Req.Response{status: 200, body: body}, integration, account_id, acc, opts)
       when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} ->
        handle_response(
          %Req.Response{status: 200, body: decoded},
          integration,
          account_id,
          acc,
          opts
        )

      {:error, _} ->
        {:error, :malformed_response}
    end
  end

  defp handle_response(%Req.Response{status: 401}, _int, _aid, _acc, _opts),
    do: {:error, :unauthorized}

  defp handle_response(%Req.Response{status: 403}, _int, _aid, _acc, _opts) do
    Logger.warning("GBP API returned 403 — API may not be enabled or access revoked")
    {:error, :api_disabled}
  end

  defp handle_response(%Req.Response{status: status, body: body}, _int, aid, _acc, _opts) do
    Logger.warning("GBP Locations API returned status #{status} for #{aid}: #{inspect(body)}")
    {:error, :bad_request}
  end

  defp extract_locations(%{"locations" => locations}, account_id) when is_list(locations) do
    # Derive a human-readable account name from the account_id
    account_name = derive_account_name(account_id)

    Enum.map(locations, fn loc ->
      # The location "name" from the API is like "locations/abc123"
      location_name = Map.get(loc, "name", "")
      # Build a fully qualified ID: "accounts/123/locations/abc123"
      qualified_id = "#{account_id}/#{location_name}"

      %{
        id: qualified_id,
        name: Map.get(loc, "title", location_name),
        account: account_name,
        store_code: Map.get(loc, "storeCode"),
        address: format_address(Map.get(loc, "storefrontAddress")),
        website: Map.get(loc, "websiteUri"),
        category: get_in(loc, ["primaryCategory", "displayName"]),
        hours: get_in(loc, ["regularHours", "periods"])
      }
    end)
  end

  defp extract_locations(_body, _account_id), do: []

  defp derive_account_name(account_id) do
    # "accounts/123" -> "Account 123"
    case String.split(account_id, "/") do
      ["accounts", id] -> "Account #{id}"
      _ -> account_id
    end
  end

  defp format_address(nil), do: nil

  defp format_address(addr) when is_map(addr) do
    [
      Map.get(addr, "addressLines", []) |> Enum.join(", "),
      Map.get(addr, "locality"),
      Map.get(addr, "administrativeArea"),
      Map.get(addr, "postalCode")
    ]
    |> Enum.reject(&(is_nil(&1) or &1 == ""))
    |> Enum.join(", ")
  end

  defp format_address(_), do: nil

  defp maybe_put_plug(req_opts, opts) do
    plug =
      Keyword.get(opts, :http_plug) ||
        Application.get_env(:metric_flow, :req_http_options, [])[:plug]

    case plug do
      nil -> req_opts
      plug -> Keyword.put(req_opts, :plug, plug)
    end
  end
end
