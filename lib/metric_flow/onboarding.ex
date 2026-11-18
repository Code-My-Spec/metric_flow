defmodule MetricFlow.Onboarding do
  @moduledoc """
  Data-source setup as one model: **connections** (one OAuth grant each —
  Google, Meta, QuickBooks) → **products** (GA4, Google Ads, …) →
  **selections** (the property / account / site each product syncs).

  This is the single API behind the setup wizard, the in-app agent's tools
  and the MCP server, so all three agree on what "connected" and "ready"
  mean and save selections under exactly the metadata keys the sync code
  reads.

  Product status, in order of progress:

    * `:not_connected`   — no grant yet for this product's connection
    * `:not_granted`     — the connection exists but the user unticked this
                           product's scope on the consent screen
    * `:reconnect`       — the token expired and cannot be refreshed
    * `:needs_selection` — connected, nothing picked to sync yet
    * `:ready`           — connected with a saved selection
  """

  use Boundary,
    deps: [MetricFlow, MetricFlow.Integrations, MetricFlow.DataSync, MetricFlow.Users],
    exports: [Tools]

  alias MetricFlow.DataSync
  alias MetricFlow.Integrations
  alias MetricFlow.Integrations.Integration
  alias MetricFlow.Users.Scope

  @connections [
    %{
      key: :google,
      name: "Google",
      description: "Analytics, Ads, Search Console, Business Profile and YouTube with one sign-in",
      products: [
        :google_analytics,
        :google_ads,
        :google_search_console,
        :google_business,
        :youtube
      ]
    },
    %{
      key: :facebook_ads,
      name: "Meta",
      description: "Facebook and Instagram ad performance",
      products: [:facebook_ads]
    },
    %{
      key: :quickbooks,
      name: "QuickBooks",
      description: "Revenue from your books",
      products: [:quickbooks]
    }
  ]

  # mode: :single saves one id, :multi saves a list. `key` is the
  # provider_metadata key the sync provider reads.
  @products %{
    google_analytics: %{
      name: "Google Analytics 4",
      noun: "property",
      gives: "Sessions, users, conversions and revenue by channel",
      mode: :single,
      key: "property_id"
    },
    google_ads: %{
      name: "Google Ads",
      noun: "ad account",
      gives: "Spend, clicks, conversions and ROAS by campaign",
      mode: :single,
      key: "customer_id"
    },
    google_search_console: %{
      name: "Search Console",
      noun: "site",
      gives: "Search clicks, impressions and rankings",
      mode: :single,
      key: "site_url"
    },
    google_business: %{
      name: "Business Profile",
      noun: "location",
      gives: "Calls, direction requests, website clicks and reviews",
      mode: :multi,
      key: "included_locations"
    },
    youtube: %{
      name: "YouTube",
      noun: "channel",
      gives: "Views, watch time, subscribers and revenue by video",
      mode: :multi,
      key: "channel_ids"
    },
    facebook_ads: %{
      name: "Meta Ads",
      noun: "ad account",
      gives: "Spend, reach, clicks and conversions by campaign",
      mode: :single,
      key: "ad_account_id"
    },
    quickbooks: %{
      name: "QuickBooks",
      noun: "income account",
      gives: "Revenue by income account",
      mode: :multi,
      key: "income_account_ids"
    }
  }

  @type product_status :: :not_connected | :not_granted | :reconnect | :needs_selection | :ready

  @doc "Connection catalog, in wizard order."
  @spec connection_keys() :: [atom()]
  def connection_keys, do: Enum.map(@connections, & &1.key)

  @doc "Product keys across all connections."
  @spec product_keys() :: [atom()]
  def product_keys, do: Enum.flat_map(@connections, & &1.products)

  @doc "Static info about one product (name, noun, what it gives, selection mode)."
  @spec product_info(atom()) :: map() | nil
  def product_info(product), do: Map.get(@products, product)

  @doc """
  Parses a connection or product key from a string without creating atoms.
  Returns `{:ok, atom}` or `:error`.
  """
  @spec parse_key(String.t() | atom()) :: {:ok, atom()} | :error
  def parse_key(key) when is_atom(key), do: parse_key(Atom.to_string(key))

  def parse_key(key) when is_binary(key) do
    Enum.find_value(connection_keys() ++ product_keys(), :error, fn k ->
      if Atom.to_string(k) == key, do: {:ok, k}
    end)
  end

  @doc """
  Every connection with its products' live status and current selection.

  Reads only the database — never calls a provider API — so it is cheap
  enough to render on every page load.
  """
  @spec status(Scope.t()) :: [map()]
  def status(%Scope{} = scope) do
    integrations = Map.new(Integrations.list_integrations(scope), &{&1.provider, &1})

    Enum.map(@connections, fn conn ->
      products = Enum.map(conn.products, &product_status(&1, integrations))
      Map.merge(conn, %{products: products, state: connection_state(products)})
    end)
  end

  @doc "Status of a single connection (see `status/1`)."
  @spec connection_status(Scope.t(), atom()) :: map() | nil
  def connection_status(scope, key), do: Enum.find(status(scope), &(&1.key == key))

  @doc """
  True when at least one product is `:ready` — enough to show a dashboard.
  """
  @spec any_ready?(Scope.t()) :: boolean()
  def any_ready?(scope) do
    scope |> status() |> Enum.flat_map(& &1.products) |> Enum.any?(&(&1.status == :ready))
  end

  @doc """
  True when no data source is connected at all (other integrations, such as
  the CodeMySpec agent connection, don't count).
  """
  @spec nothing_connected?(Scope.t()) :: boolean()
  def nothing_connected?(scope) do
    scope |> status() |> Enum.all?(&(&1.state == :not_connected))
  end

  defp product_status(product, integrations) do
    info = Map.fetch!(@products, product)
    integration = Map.get(integrations, product)
    selected = selected_ids(product, integration)

    status =
      cond do
        is_nil(integration) -> google_or_not_connected(product, integrations)
        unusable_token?(integration) -> :reconnect
        selected == [] -> :needs_selection
        true -> :ready
      end

    Map.merge(info, %{
      key: product,
      status: status,
      selected: selected,
      connected_as: integration && get_in(integration.provider_metadata || %{}, ["email"])
    })
  end

  # A Google product with no row of its own, while a sibling Google product
  # is connected, means the user declined that product's scope.
  defp google_or_not_connected(product, integrations) do
    google = Enum.find(@connections, &(&1.key == :google)).products

    if product in google and Enum.any?(google, &Map.has_key?(integrations, &1)),
      do: :not_granted,
      else: :not_connected
  end

  defp unusable_token?(integration) do
    Integration.expired?(integration) and not Integration.has_refresh_token?(integration)
  end

  defp connection_state(products) do
    statuses = Enum.map(products, & &1.status)

    cond do
      Enum.all?(statuses, &(&1 == :not_connected)) -> :not_connected
      :reconnect in statuses -> :reconnect
      :needs_selection in statuses -> :needs_selection
      true -> :done
    end
  end

  defp selected_ids(_product, nil), do: []

  defp selected_ids(product, %Integration{provider_metadata: meta}) do
    meta = meta || %{}

    case product do
      :quickbooks ->
        List.wrap(meta["income_account_ids"] || meta["income_account_id"])

      :facebook_ads ->
        List.wrap(meta["ad_account_id"] || meta["property_id"])

      _ ->
        List.wrap(meta[@products[product].key])
    end
    |> Enum.reject(&(&1 in [nil, ""]))
  end

  @doc """
  The in-app path that starts a connection's OAuth flow. Send the user's
  browser here (or give it to the user as a link); after consent they land
  on `return_to`.
  """
  @spec connect_path(atom(), String.t()) :: String.t()
  def connect_path(connection, return_to \\ "/app/onboarding/connect")

  def connect_path(:google, return_to),
    do: "/app/integrations/oauth/google_bundle?" <> URI.encode_query(%{return_to: return_to})

  def connect_path(provider, return_to) when provider in [:facebook_ads, :quickbooks],
    do: "/app/integrations/oauth/#{provider}?" <> URI.encode_query(%{return_to: return_to})

  @doc """
  Lists what a product can sync — GA4 properties, ad accounts, sites,
  locations, income accounts — as `[%{id, name}]`, live from the provider.

  For Business Profile this also records every business account the token
  can see, so locations across all of them are offered in one list.
  """
  @spec list_options(Scope.t(), atom()) :: {:ok, [map()]} | {:error, term()}
  def list_options(%Scope{} = scope, product) do
    result =
      case product do
        :google_analytics -> Integrations.list_google_accounts(scope, :google_analytics)
        :google_ads -> Integrations.list_google_ads_customers(scope)
        :google_search_console -> Integrations.list_search_console_sites(scope)
        :facebook_ads -> Integrations.list_facebook_ads_accounts(scope)
        :quickbooks -> Integrations.list_quickbooks_accounts(scope)
        :google_business -> list_business_locations(scope)
        :youtube -> list_youtube_channels(scope)
        _ -> {:error, :unknown_product}
      end

    with {:ok, options} <- result do
      {:ok, Enum.map(options, &Map.take(&1, [:id, :name, :account]))}
    end
  end

  defp list_youtube_channels(scope) do
    with {:ok, %{channels: channels}} <- Integrations.youtube_selection(scope, nil),
         do: {:ok, channels}
  end

  defp list_business_locations(scope) do
    with {:ok, accounts} <- Integrations.list_google_business_accounts(scope),
         {:ok, _} <-
           Integrations.update_provider_metadata(scope, :google_business, %{
             "google_business_account_ids" => Enum.map(accounts, & &1.id)
           }) do
      if accounts == [],
        do: {:ok, []},
        else: Integrations.list_google_business_locations(scope)
    end
  end

  @doc """
  Saves what a product should sync and queues a first sync.

  `ids` is a list; single-selection products take exactly one. Returns
  `{:ok, %{product, selected, sync}}`, where `sync` is `:queued` or the
  reason it could not be queued (the selection is saved either way).
  """
  @spec save_selection(Scope.t(), atom(), [String.t()]) :: {:ok, map()} | {:error, term()}
  def save_selection(%Scope{} = scope, product, ids) when is_list(ids) do
    ids = ids |> Enum.map(&to_string/1) |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))

    with {:ok, info} <- fetch_product(product),
         :ok <- validate_count(info, ids),
         {:ok, _} <- write_selection(scope, product, ids) do
      sync =
        case DataSync.sync_integration(scope, product) do
          {:ok, _job} -> :queued
          {:error, reason} -> reason
        end

      {:ok, %{product: product, selected: ids, sync: sync}}
    end
  end

  # YouTube validates that each channel belongs to the connected login.
  defp write_selection(scope, :youtube, ids),
    do: Integrations.save_youtube_channels(scope, nil, ids)

  defp write_selection(scope, product, ids),
    do: Integrations.update_provider_metadata(scope, product, metadata_for(product, ids))

  defp fetch_product(product) do
    case Map.fetch(@products, product) do
      {:ok, info} -> {:ok, info}
      :error -> {:error, :unknown_product}
    end
  end

  defp validate_count(_info, []), do: {:error, :nothing_selected}
  defp validate_count(%{mode: :single}, [_]), do: :ok
  defp validate_count(%{mode: :single}, _), do: {:error, :select_exactly_one}
  defp validate_count(%{mode: :multi}, _), do: :ok

  # QuickBooks sync reads the list; the singular key is kept for older readers.
  defp metadata_for(:quickbooks, ids),
    do: %{"income_account_ids" => ids, "income_account_id" => List.first(ids)}

  defp metadata_for(product, ids) do
    case @products[product] do
      %{mode: :single, key: key} -> %{key => hd(ids)}
      %{mode: :multi, key: key} -> %{key => ids}
    end
  end

  @doc "Disconnects a product (revoking its token where the provider supports it)."
  @spec disconnect(Scope.t(), atom()) :: :ok | {:error, term()}
  def disconnect(%Scope{} = scope, product) do
    with {:ok, _} <- fetch_product(product) do
      # Google products share one grant; revoking the token for one would
      # silently disconnect its siblings, so only the last one revokes.
      result =
        if shares_google_grant?(scope, product),
          do: Integrations.delete_integration(scope, product),
          else: Integrations.disconnect(scope, product)

      case result do
        {:ok, _} -> :ok
        :ok -> :ok
        other -> other
      end
    end
  end

  defp shares_google_grant?(scope, product) do
    google = Enum.find(@connections, &(&1.key == :google)).products

    product in google and
      Enum.any?(
        Integrations.list_integrations(scope),
        &(&1.provider in google and &1.provider != product)
      )
  end

  @doc "Queues a sync for a product now."
  @spec sync_now(Scope.t(), atom()) :: {:ok, map()} | {:error, term()}
  def sync_now(%Scope{} = scope, product) do
    with {:ok, _} <- fetch_product(product),
         {:ok, job} <- DataSync.sync_integration(scope, product) do
      {:ok, %{product: product, sync_job_id: job.id}}
    end
  end

  @doc "Human sentence for an error atom, for UI flashes and agent replies."
  @spec explain_error(term()) :: String.t()
  def explain_error(:not_found), do: "That data source isn't connected yet."
  def explain_error(:nothing_selected), do: "Pick at least one to sync."
  def explain_error(:select_exactly_one), do: "Pick exactly one."
  def explain_error(:unknown_product), do: "Unknown data source."
  def explain_error(:api_disabled), do: "The provider's API is disabled for this account."
  def explain_error(:token_expired), do: "The connection expired — reconnect to continue."

  def explain_error(:unauthorized),
    do: "Only account owners, admins and account managers can change data sources."

  def explain_error(:no_youtube_channels), do: "No channel on this Google account."

  def explain_error(:missing_youtube_scopes),
    do: "YouTube access wasn't granted — reconnect Google and tick YouTube."

  def explain_error(:no_accounts_configured),
    do: "No Business Profile accounts are visible to this Google login."

  def explain_error(reason), do: "Something went wrong (#{inspect(reason)})."
end
