defmodule MetricFlowWeb.IntegrationLive.Connect do
  @moduledoc """
  OAuth connection flow for linking marketing platforms to a user account.

  Handles three distinct route patterns via handle_params/3, distinguished by
  the live action assigned in the router:

  - `:index` (`/integrations/connect`) — platform selection grid showing all
    configured providers with their current connection status. The "connect"
    event initiates the OAuth flow by redirecting the browser to the
    controller-based OAuth request route.

  - `:detail` (`/integrations/connect/:provider`) — per-platform detail view
    showing the OAuth initiation anchor and connection status.

  - `:accounts` (`/integrations/connect/:provider/accounts`) — account
    selection view for choosing which ad accounts or properties to sync.

  OAuth callback handling is performed by `IntegrationOAuthController`, which
  can write to the Phoenix session (required for Assent state verification).
  """

  use MetricFlowWeb, :live_view

  alias MetricFlow.Integrations

  # Each platform has its own OAuth connection and integration record.
  @canonical_providers [
    %{key: :google_analytics, name: "Google Analytics", description: "Website traffic and user behavior analytics"},
    %{key: :google_ads, name: "Google Ads", description: "Paid search and display advertising"},
    %{key: :google_search_console, name: "Google Search Console", description: "Search performance and indexing data"},
    %{key: :facebook_ads, name: "Facebook", description: "Facebook and Instagram advertising"},
    %{key: :quickbooks, name: "QuickBooks", description: "Financial accounting and bookkeeping"}
  ]

  # Display metadata for providers, keyed by provider atom.
  @provider_metadata %{
    google_analytics: %{name: "Google Analytics", description: "Website traffic and user behavior analytics"},
    google_ads: %{name: "Google Ads", description: "Paid search and display advertising"},
    google_search_console: %{name: "Google Search Console", description: "Search performance and indexing data"},
    facebook_ads: %{name: "Facebook", description: "Facebook and Instagram advertising"},
    quickbooks: %{name: "QuickBooks", description: "Financial accounting and bookkeeping"}
  }

  # ---------------------------------------------------------------------------
  # Render
  # ---------------------------------------------------------------------------

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active_account_name={assigns[:active_account_name]}>
      <div class="mx-auto max-w-3xl mf-content px-4 py-8">
        <div class="mb-8">
          <h1 class="text-2xl font-bold">Connect a Provider</h1>
          <p class="mt-1 text-base-content/60">
            Authenticate with your marketing providers to start syncing data
          </p>
        </div>

        <%= case @view_mode do %>
          <% :selection -> %>
            <%= render_platform_selection(assigns) %>
          <% :detail -> %>
            <%= render_platform_detail(assigns) %>
          <% :result -> %>
            <%= render_result(assigns) %>
          <% :accounts -> %>
            <%= render_account_selection(assigns) %>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp render_platform_selection(assigns) do
    ~H"""
    <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
      <div
        :for={provider <- @providers}
        data-platform={provider.key}
        class="mf-card p-5"
      >
        <div class="mb-3">
          <div class="w-10 h-10 rounded bg-base-300/40 flex items-center justify-center mb-3">
            <span class="text-xs font-bold text-base-content/60 uppercase">
              {String.slice(provider.name, 0, 2)}
            </span>
          </div>
          <h3 class="font-semibold">{provider.name}</h3>
          <p class="text-sm text-base-content/60 mt-1">{provider.description}</p>
        </div>

        <div class="flex flex-col mt-4">
          <span :if={provider_connected?(@integrations, provider.key)} class="badge badge-success self-start">
            Connected
          </span>
          <span :if={not provider_connected?(@integrations, provider.key)} class="badge badge-ghost self-start">
            Not connected
          </span>

          <button
            data-role="connect-button"
            phx-click="connect"
            phx-value-provider={provider.key}
            class="btn btn-primary btn-sm w-full sm:w-auto mt-2"
          >
            {if provider_connected?(@integrations, provider.key), do: "Reconnect", else: "Connect"}
          </button>
        </div>
      </div>
    </div>
    """
  end

  defp render_platform_detail(assigns) do
    ~H"""
    <div class="mf-card max-w-sm mx-auto p-6">
      <h2 class="text-xl font-semibold mb-2">{@platform.name}</h2>

      <div :if={not is_nil(@integration)} class="mb-4">
        <span class="badge badge-success">Connected</span>
        <p class="text-sm mt-2 text-base-content/60">
          Connected as {@integration.provider_metadata["email"] || "unknown"}
        </p>

        <% meta_key = metadata_key_for_provider(String.to_existing_atom(@provider)) %>
        <div :if={@integration.provider_metadata[meta_key]} class="mt-2 p-2 bg-base-200 rounded text-sm">
          <span class="font-medium">{account_labels(String.to_existing_atom(@provider)).id_label}:</span>
          <span class="text-base-content/70">{@integration.provider_metadata[meta_key]}</span>
        </div>

        <div class="flex flex-col gap-2 mt-3">
          <.link
            navigate={~p"/integrations/connect/#{@provider}/accounts"}
            data-role="select-accounts-button"
            class="btn btn-secondary btn-sm w-full sm:w-auto"
          >
            Select Accounts
          </.link>
          <a
            :if={@authorize_url}
            data-role="oauth-connect-button"
            href={@authorize_url}
            target="_blank"
            rel="noopener noreferrer"
            class="btn btn-primary btn-sm w-full sm:w-auto"
          >
            Reconnect
          </a>
          <p :if={is_nil(@authorize_url)} class="text-sm text-base-content/60">
            Reconnect is not available — this provider is not currently configured for OAuth.
          </p>
        </div>
      </div>
      <div :if={is_nil(@integration)} class="mb-4">
        <span class="badge badge-ghost">Not connected</span>
        <p class="text-sm mt-2 text-base-content/60">
          {@platform.description}
        </p>
      </div>

      <div data-role="account-selection" class="mb-4">
        <p class="text-sm text-base-content/60">
          Connect your {@platform.name} account to enable data syncing from this provider.
        </p>
      </div>

      <div :if={is_nil(@integration)} class="mt-4">
        <a
          :if={@authorize_url}
          data-role="oauth-connect-button"
          href={@authorize_url}
          target="_blank"
          rel="noopener noreferrer"
          class="btn btn-primary w-full"
        >
          Connect {@platform.name}
        </a>
        <div :if={is_nil(@authorize_url)} class="alert alert-warning text-sm">
          <svg xmlns="http://www.w3.org/2000/svg" class="stroke-current shrink-0 h-5 w-5" fill="none" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
          </svg>
          <span>OAuth is not configured for this provider. Please contact your administrator.</span>
        </div>
      </div>

      <div class="mt-4">
        <.link navigate={~p"/integrations"} class="btn btn-ghost btn-sm">
          Back to integrations
        </.link>
      </div>
    </div>
    """
  end

  defp render_result(assigns) do
    ~H"""
    <div class="mf-card max-w-sm mx-auto p-6">
      <%= if @result_status == :connected do %>
        <div class="text-center">
          <div class="text-success text-4xl mb-3">&#10003;</div>
          <h2 class="text-xl font-semibold mb-2">Integration Active</h2>
          <p class="text-sm text-base-content/60 mb-4">
            Your {@platform.name} account is connected and ready to sync data.
          </p>
          <span class="badge badge-success mb-4">Active</span>
          <div class="flex flex-col gap-2 mt-4">
            <.link navigate={~p"/integrations"} class="btn btn-primary w-full">
              View Integrations
            </.link>
            <.link navigate={~p"/integrations/connect"} class="btn btn-ghost btn-sm">
              Connect another platform
            </.link>
          </div>
        </div>
      <% else %>
        <div class="text-center">
          <div class="text-error text-4xl mb-3">&#10007;</div>
          <h2 class="text-xl font-semibold text-error mb-2">Connection Failed</h2>
          <p class="text-sm text-base-content/60 mb-4">
            {@error_message}
          </p>
          <div class="flex flex-col gap-2 mt-4">
            <.link navigate={~p"/integrations/connect/#{@provider}"} class="btn btn-primary w-full">
              Try again
            </.link>
            <.link navigate={~p"/integrations"} class="btn btn-ghost btn-sm">
              Back to integrations
            </.link>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_account_selection(assigns) do
    assigns = assign(assigns, :account_labels, account_labels(String.to_existing_atom(assigns.provider)))

    ~H"""
    <div class="mf-card max-w-lg mx-auto p-6">
      <h2 class="text-xl font-semibold mb-2">{@platform.name} — Select Accounts</h2>
      <p class="text-sm text-base-content/60 mb-4">
        {@account_labels.chooser_text}
      </p>

      <form phx-submit="save_account_selection" data-role="account-selection" class="space-y-4 mb-6">
        <%= if @accounts != [] do %>
          <div data-role="account-list" class="space-y-2">
            <p class="text-sm font-medium mb-2">{"Available #{@account_labels.list_heading}:"}</p>
            <div
              :for={property <- @accounts}
              class="flex items-center gap-3 p-3 bg-base-200 rounded hover:bg-base-300 transition-colors"
              data-role="account-option"
            >
              <input
                type="radio"
                name="property_id"
                value={property.id}
                data-role="account-checkbox"
                class="radio radio-sm radio-primary"
                checked={@selected_property_id == property.id}
                phx-click="select_property"
                phx-value-property_id={property.id}
              />
              <div>
                <span class="text-sm font-medium">{property.name}</span>
                <span class="text-xs text-base-content/60 block">{property.account} &mdash; {property.id}</span>
              </div>
            </div>
          </div>
        <% end %>

        <%= if @accounts_error == :api_disabled or @accounts == [] do %>
          <div data-role="manual-entry" class="space-y-2">
            <%= if @accounts_error == :api_disabled do %>
              <div class="alert alert-warning text-sm mb-3">
                <svg xmlns="http://www.w3.org/2000/svg" class="stroke-current shrink-0 h-5 w-5" fill="none" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
                </svg>
                <span>Could not fetch accounts automatically. You can enter your account ID manually below.</span>
              </div>
            <% end %>

            <%= if @accounts != [] do %>
              <div class="divider text-xs text-base-content/40">or enter manually</div>
              <div class="flex items-center gap-3 p-3 bg-base-200 rounded">
                <input
                  type="radio"
                  name="property_id"
                  value="manual"
                  class="radio radio-sm radio-primary"
                  data-role="manual-radio"
                  checked={@selected_property_id == "manual"}
                  phx-click="select_property"
                  phx-value-property_id="manual"
                />
                <span class="text-sm font-medium">Enter manually</span>
              </div>
            <% end %>

            <label class="form-control w-full">
              <div class="label">
                <span class="label-text text-sm">{@account_labels.id_label}</span>
              </div>
              <input
                type="text"
                name="manual_property_id"
                value={@manual_property_id}
                placeholder={account_labels(String.to_existing_atom(@provider)).id_label}
                data-role="manual-property-input"
                class="input input-bordered input-sm w-full"
              />
              <div class="label">
                <span class="label-text-alt text-xs text-base-content/50">
                  {@account_labels.help_text}
                </span>
              </div>
            </label>
          </div>
        <% end %>

        <div class="flex flex-col gap-2 mt-4">
          <button
            type="submit"
            data-role="save-selection"
            class="btn btn-primary w-full"
          >
            Save Selection
          </button>

          <.link navigate={~p"/integrations/connect/#{@provider}"} class="btn btn-ghost btn-sm">
            Back
          </.link>
        </div>
      </form>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Mount
  # ---------------------------------------------------------------------------

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope
    integrations = Integrations.list_integrations(scope)
    providers = build_provider_list(integrations)

    socket =
      socket
      |> assign(:integrations, integrations)
      |> assign(:providers, providers)
      |> assign(:view_mode, :selection)
      |> assign(:integration, nil)
      |> assign(:platform, nil)
      |> assign(:provider, nil)
      |> assign(:authorize_url, nil)
      |> assign(:result_status, nil)
      |> assign(:error_message, nil)
      |> assign(:accounts, [])
      |> assign(:accounts_error, nil)
      |> assign(:selected_property_id, nil)
      |> assign(:manual_property_id, "")

    {:ok, socket}
  end

  # ---------------------------------------------------------------------------
  # Handle params — route dispatch by live action
  # ---------------------------------------------------------------------------

  @impl true
  def handle_params(_params, _uri, %{assigns: %{live_action: :index}} = socket) do
    {:noreply, assign(socket, :view_mode, :selection)}
  end

  def handle_params(
        %{"provider" => provider},
        _uri,
        %{assigns: %{live_action: :accounts}} = socket
      ) do
    handle_accounts_params(provider, socket)
  end

  def handle_params(
        %{"provider" => provider},
        _uri,
        %{assigns: %{live_action: :detail}} = socket
      ) do
    handle_provider_params(provider, socket)
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, assign(socket, :view_mode, :selection)}
  end

  # ---------------------------------------------------------------------------
  # Event handlers
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("connect", %{"provider" => provider_str}, socket) do
    {:noreply, redirect(socket, to: ~p"/integrations/oauth/#{provider_str}")}
  end

  def handle_event("save_account_selection", params, socket) do
    scope = socket.assigns.current_scope
    provider_str = socket.assigns.provider
    provider_atom = String.to_existing_atom(provider_str)

    # Determine the selected account ID from either the radio selection or manual input
    account_id =
      case Map.get(params, "property_id") do
        "manual" -> String.trim(Map.get(params, "manual_property_id", ""))
        id when is_binary(id) and id != "" -> id
        _ -> String.trim(Map.get(params, "manual_property_id", ""))
      end

    if account_id == "" do
      {:noreply, put_flash(socket, :error, "Please select or enter an account ID.")}
    else
      metadata_key = metadata_key_for_provider(provider_atom)

      case Integrations.update_provider_metadata(scope, provider_atom, %{metadata_key => account_id}) do
        {:ok, _integration} ->
          {:noreply,
           socket
           |> put_flash(:info, "Account selection saved successfully.")
           |> push_navigate(to: ~p"/integrations/connect/#{provider_str}")}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, "Failed to save selection: #{inspect(reason)}")}
      end
    end
  end

  def handle_event("select_property", %{"property_id" => property_id}, socket) do
    {:noreply, assign(socket, :selected_property_id, property_id)}
  end

  # ---------------------------------------------------------------------------
  # Private helpers — route handlers
  # ---------------------------------------------------------------------------

  # Valid provider keys include both canonical providers and dynamically configured ones.
  # Compile-time keys from @provider_metadata, runtime keys from Integrations.list_providers().
  @canonical_provider_keys Map.keys(@provider_metadata)

  defp handle_provider_params(provider_str, socket) do
    case validate_provider(provider_str) do
      :error ->
        {:noreply, push_navigate(socket, to: ~p"/integrations/connect")}

      {:ok, provider_atom} ->
        {view_mode, extra_assigns} = detect_result_state(socket.assigns.flash)

        {:noreply,
         socket
         |> assign(:view_mode, view_mode)
         |> assign(:platform, resolve_platform(provider_atom, provider_str))
         |> assign(:integration, fetch_existing_integration(socket, provider_atom))
         |> assign(:provider, provider_str)
         |> assign(:authorize_url, fetch_authorize_url(provider_atom))
         |> assign(extra_assigns)}
    end
  end

  defp handle_accounts_params(provider_str, socket) do
    case validate_provider(provider_str) do
      :error ->
        {:noreply, push_navigate(socket, to: ~p"/integrations/connect")}

      {:ok, provider_atom} ->
        integration = fetch_existing_integration(socket, provider_atom)

        if is_nil(integration) do
          {:noreply,
           socket
           |> put_flash(:error, "Please connect #{provider_str} first before selecting accounts.")
           |> push_navigate(to: ~p"/integrations/connect/#{provider_str}")}
        else
          {accounts, accounts_error} = fetch_provider_accounts(socket, provider_atom, integration)

          meta_key = metadata_key_for_provider(provider_atom)

          selected_property_id =
            get_in(integration.provider_metadata || %{}, [meta_key])

          {:noreply,
           socket
           |> assign(:view_mode, :accounts)
           |> assign(:platform, resolve_platform(provider_atom, provider_str))
           |> assign(:provider, provider_str)
           |> assign(:integration, integration)
           |> assign(:accounts, accounts)
           |> assign(:accounts_error, accounts_error)
           |> assign(:selected_property_id, selected_property_id)
           |> assign(:manual_property_id, selected_property_id || "")}
        end
    end
  end

  defp validate_provider(provider_str) do
    provider_atom = String.to_existing_atom(provider_str)
    configured_keys = Integrations.list_providers()

    if provider_atom in @canonical_provider_keys or provider_atom in configured_keys,
      do: {:ok, provider_atom},
      else: :error
  rescue
    ArgumentError -> :error
  end

  defp resolve_platform(provider_atom, provider_str) do
    find_provider_metadata(provider_atom) ||
      build_unknown_provider(provider_atom, provider_str)
  end

  defp fetch_existing_integration(socket, provider_atom) do
    case Integrations.get_integration(socket.assigns.current_scope, provider_atom) do
      {:ok, integration} -> integration
      {:error, _} -> nil
    end
  end

  defp fetch_authorize_url(provider_atom) do
    alias MetricFlow.Integrations.OAuthStateStore

    case Integrations.authorize_url(provider_atom) do
      {:ok, %{url: url, session_params: session_params}} ->
        state = Map.get(session_params, :state) || Map.get(session_params, "state")
        if state, do: OAuthStateStore.store(state, session_params)
        url

      {:ok, %{url: url}} ->
        url

      {:error, _} ->
        nil
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers — account fetching
  # ---------------------------------------------------------------------------

  defp fetch_provider_accounts(socket, :google_analytics, _integration) do
    scope = socket.assigns.current_scope

    case Integrations.list_google_accounts(scope, :google_analytics) do
      {:ok, accounts} -> {accounts, nil}
      {:error, :api_disabled} -> {[], :api_disabled}
      {:error, reason} -> {[], reason}
    end
  end

  defp fetch_provider_accounts(socket, :google_ads, _integration) do
    scope = socket.assigns.current_scope

    case Integrations.list_google_ads_customers(scope) do
      {:ok, accounts} -> {accounts, nil}
      {:error, :api_disabled} -> {[], :api_disabled}
      {:error, reason} -> {[], reason}
    end
  end

  defp fetch_provider_accounts(socket, :google_search_console, _integration) do
    scope = socket.assigns.current_scope

    case Integrations.list_search_console_sites(scope) do
      {:ok, sites} -> {sites, nil}
      {:error, :api_disabled} -> {[], :api_disabled}
      {:error, reason} -> {[], reason}
    end
  end

  defp fetch_provider_accounts(_socket, _provider, _integration) do
    {[], nil}
  end

  # ---------------------------------------------------------------------------
  # Private helpers — provider list construction
  # ---------------------------------------------------------------------------

  # Build the union of:
  # 1. All canonical OAuth providers (always shown)
  # 2. Providers configured via Application env
  # 3. Providers with existing user integrations
  #
  # This shows OAuth providers (Google, Facebook, QuickBooks), not individual
  # data platforms (Google Ads, Google Analytics).
  defp build_provider_list(integrations) do
    configured_keys = MapSet.new(Integrations.list_providers())
    canonical_keys = MapSet.new(Enum.map(@canonical_providers, & &1.key))
    integration_keys = MapSet.new(Enum.map(integrations, & &1.provider))

    all_keys =
      configured_keys
      |> MapSet.union(canonical_keys)
      |> MapSet.union(integration_keys)

    all_keys
    |> Enum.map(fn key ->
      find_provider_metadata(key) || build_unknown_provider(key, Atom.to_string(key))
    end)
    |> Enum.sort_by(& &1.name)
  end

  defp find_provider_metadata(provider_key) do
    case Map.get(@provider_metadata, provider_key) do
      nil -> nil
      meta -> Map.put(meta, :key, provider_key)
    end
  end

  defp build_unknown_provider(provider_atom, provider_str) do
    %{key: provider_atom, name: provider_display_name(provider_str), description: ""}
  end

  # ---------------------------------------------------------------------------
  # Private helpers — flash-based result state
  # ---------------------------------------------------------------------------

  defp detect_result_state(%{"info" => "Successfully connected!"}) do
    {:result, %{result_status: :connected}}
  end

  defp detect_result_state(%{"error" => msg}) when msg not in [nil, ""] do
    {:result, %{result_status: :error, error_message: msg}}
  end

  defp detect_result_state(_flash) do
    {:detail, %{}}
  end

  # ---------------------------------------------------------------------------
  # Private helpers — utilities
  # ---------------------------------------------------------------------------

  # Maps provider atoms to the metadata key used to store the selected account ID.
  defp metadata_key_for_provider(:google_analytics), do: "property_id"
  defp metadata_key_for_provider(:google_ads), do: "customer_id"
  defp metadata_key_for_provider(:google_search_console), do: "site_url"
  defp metadata_key_for_provider(:quickbooks), do: "realm_id"
  defp metadata_key_for_provider(_), do: "property_id"

  defp provider_connected?(integrations, provider_key) do
    Enum.any?(integrations, fn i -> i.provider == provider_key end)
  end

  defp provider_display_name(provider) when is_binary(provider) do
    case Map.get(@provider_metadata, String.to_existing_atom(provider)) do
      %{name: name} -> name
      nil -> derive_display_name(provider)
    end
  rescue
    ArgumentError -> derive_display_name(provider)
  end

  defp account_labels(:google_analytics) do
    %{
      chooser_text: "Choose which GA4 property to sync data from.",
      list_heading: "GA4 Properties",
      id_label: "GA4 Property ID",
      help_text: "Find this in Google Analytics under Admin → Property Settings"
    }
  end

  defp account_labels(:google_ads) do
    %{
      chooser_text: "Choose which Google Ads customer account to sync data from.",
      list_heading: "Customer Accounts",
      id_label: "Customer ID",
      help_text: "Find this in Google Ads under the account selector (10-digit number)"
    }
  end

  defp account_labels(:google_search_console) do
    %{
      chooser_text: "Choose which site to sync search data from.",
      list_heading: "Verified Sites",
      id_label: "Site URL",
      help_text: "The property URL as shown in Google Search Console"
    }
  end

  defp account_labels(:facebook_ads) do
    %{
      chooser_text: "Choose which ad account to sync data from.",
      list_heading: "Ad Accounts",
      id_label: "Ad Account ID",
      help_text: "Find this in Facebook Business Manager under Ad Accounts"
    }
  end

  defp account_labels(:quickbooks) do
    %{
      chooser_text: "Choose which company to sync data from.",
      list_heading: "Companies",
      id_label: "Company ID (Realm ID)",
      help_text: "Find this in QuickBooks under Settings → Account and Settings"
    }
  end

  defp account_labels(_provider) do
    %{
      chooser_text: "Choose which account to sync data from.",
      list_heading: "Accounts",
      id_label: "Account ID",
      help_text: "Enter the account identifier from your provider's settings"
    }
  end

  defp derive_display_name(provider) do
    provider
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map_join(" ", &String.capitalize/1)
  end
end
