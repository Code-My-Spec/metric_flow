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

  # Canonical set of supported marketing platforms always shown in the UI.
  @canonical_platforms [
    %{key: :google_ads, name: "Google Ads", description: "Paid search and display advertising"},
    %{key: :facebook_ads, name: "Facebook Ads", description: "Social media advertising on Facebook and Instagram"},
    %{key: :google_analytics, name: "Google Analytics", description: "Website traffic and user behavior analytics"},
    %{key: :quickbooks, name: "QuickBooks", description: "Financial accounting and bookkeeping"}
  ]

  # Extended display metadata used for name lookup on dynamically configured providers.
  @platform_metadata %{
    google_ads: %{name: "Google Ads", description: "Paid search and display advertising"},
    facebook_ads: %{name: "Facebook Ads", description: "Social media advertising on Facebook and Instagram"},
    google_analytics: %{name: "Google Analytics", description: "Website traffic and user behavior analytics"},
    quickbooks: %{name: "QuickBooks", description: "Financial accounting and bookkeeping"}
  }

  # ---------------------------------------------------------------------------
  # Render
  # ---------------------------------------------------------------------------

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-3xl mf-content px-4 py-8">
        <div class="mb-8">
          <h1 class="text-2xl font-bold">Connect a Platform</h1>
          <p class="mt-1 text-base-content/60">
            Link your marketing accounts to start syncing data
          </p>
        </div>

        <%= case @view_mode do %>
          <% :selection -> %>
            <%= render_platform_selection(assigns) %>
          <% :detail -> %>
            <%= render_platform_detail(assigns) %>
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
        :for={platform <- @platforms}
        data-platform={platform.key}
        class="mf-card p-5"
      >
        <div class="mb-3">
          <div class="w-10 h-10 rounded bg-base-300/40 flex items-center justify-center mb-3">
            <span class="text-xs font-bold text-base-content/60 uppercase">
              {String.slice(platform.name, 0, 2)}
            </span>
          </div>
          <h3 class="font-semibold">{platform.name}</h3>
          <p class="text-sm text-base-content/60 mt-1">{platform.description}</p>
        </div>

        <div class="flex flex-col mt-4">
          <span :if={platform_connected?(@integrations, platform.key)} class="badge badge-success self-start">
            Connected
          </span>
          <span :if={not platform_connected?(@integrations, platform.key)} class="badge badge-ghost self-start">
            Not connected
          </span>

          <button
            data-role="connect-button"
            phx-click="connect"
            phx-value-provider={platform.key}
            class="btn btn-primary btn-sm w-full sm:w-auto mt-2"
          >
            {if platform_connected?(@integrations, platform.key), do: "Reconnect", else: "Connect"}
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
        <a
          :if={@authorize_url}
          data-role="oauth-connect-button"
          href={@authorize_url}
          target="_blank"
          rel="noopener noreferrer"
          class="btn btn-primary btn-sm w-full sm:w-auto mt-2"
        >
          Reconnect
        </a>
      </div>
      <div :if={is_nil(@integration)} class="mb-4">
        <span class="badge badge-ghost">Not connected</span>
        <p class="text-sm mt-2 text-base-content/60">
          {@platform.description}
        </p>
      </div>

      <div data-role="account-selection" class="mb-4">
        <p class="text-sm text-base-content/60">
          Connect your {@platform.name} account to begin syncing data.
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
      </div>

      <div class="mt-4">
        <.link navigate={~p"/integrations"} class="btn btn-ghost btn-sm">
          Back to integrations
        </.link>
      </div>
    </div>
    """
  end

  defp render_account_selection(assigns) do
    ~H"""
    <div class="mf-card max-w-sm mx-auto p-6">
      <h2 class="text-xl font-semibold mb-2">{@platform.name} — Select Accounts</h2>
      <p class="text-sm text-base-content/60 mb-4">
        Choose which accounts or properties to sync.
      </p>

      <div data-role="account-selection" class="space-y-3 mb-6">
        <div data-role="account-list">
          <p class="text-sm text-base-content/60 mb-2">
            Select the accounts or properties you want to sync:
          </p>
          <div class="flex items-center gap-2 p-3 bg-base-200 rounded">
            <input
              type="checkbox"
              data-role="account-checkbox"
              class="checkbox checkbox-sm"
              checked
            />
            <span class="text-sm">All accounts</span>
          </div>
        </div>
      </div>

      <div class="flex flex-col gap-2">
        <button
          data-role="save-selection"
          phx-click="save_account_selection"
          class="btn btn-primary w-full"
        >
          Save Selection
        </button>

        <.link navigate={~p"/integrations/connect/#{@provider}"} class="btn btn-ghost btn-sm">
          Back
        </.link>
      </div>
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
    platforms = build_platform_list(integrations)

    socket =
      socket
      |> assign(:integrations, integrations)
      |> assign(:platforms, platforms)
      |> assign(:view_mode, :selection)
      |> assign(:integration, nil)
      |> assign(:platform, nil)
      |> assign(:provider, nil)
      |> assign(:authorize_url, nil)

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

  def handle_event("save_account_selection", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/integrations")}
  end

  # ---------------------------------------------------------------------------
  # Private helpers — route handlers
  # ---------------------------------------------------------------------------

  defp handle_provider_params(provider_str, socket) do
    result =
      try do
        provider_atom = String.to_existing_atom(provider_str)
        scope = socket.assigns.current_scope

        integration =
          case Integrations.get_integration(scope, provider_atom) do
            {:ok, integration} -> integration
            {:error, _} -> nil
          end

        platform =
          find_platform_metadata(provider_atom) ||
            build_unknown_platform(provider_atom, provider_str)

        authorize_url =
          case Integrations.authorize_url(provider_atom) do
            {:ok, %{url: url}} -> url
            {:error, _} -> nil
          end

        {:ok, platform, integration, authorize_url}
      rescue
        ArgumentError -> :unknown_provider
      end

    case result do
      :unknown_provider ->
        {:noreply, push_navigate(socket, to: ~p"/integrations/connect")}

      {:ok, platform, integration, authorize_url} ->
        {:noreply,
         socket
         |> assign(:view_mode, :detail)
         |> assign(:platform, platform)
         |> assign(:integration, integration)
         |> assign(:provider, provider_str)
         |> assign(:authorize_url, authorize_url)}
    end
  end

  defp handle_accounts_params(provider_str, socket) do
    result =
      try do
        provider_atom = String.to_existing_atom(provider_str)

        platform =
          find_platform_metadata(provider_atom) ||
            build_unknown_platform(provider_atom, provider_str)

        {:ok, platform}
      rescue
        ArgumentError -> :unknown_provider
      end

    case result do
      :unknown_provider ->
        {:noreply, push_navigate(socket, to: ~p"/integrations/connect")}

      {:ok, platform} ->
        {:noreply,
         socket
         |> assign(:view_mode, :accounts)
         |> assign(:platform, platform)
         |> assign(:provider, provider_str)}
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers — platform list construction
  # ---------------------------------------------------------------------------

  # Build the union of:
  # 1. All canonical marketing platforms (always shown)
  # 2. Providers configured via Application env but not in the canonical list
  # 3. Providers with existing user integrations not covered above
  #
  # This ensures:
  # - Production always shows Google Ads, Facebook Ads, Google Analytics, QuickBooks
  # - Tests see their stub providers plus canonical platforms
  # - Legacy integrations remain visible even if their provider is no longer configured
  defp build_platform_list(integrations) do
    configured_keys = MapSet.new(Integrations.list_providers())
    canonical_keys = MapSet.new(Enum.map(@canonical_platforms, & &1.key))
    integration_keys = MapSet.new(Enum.map(integrations, & &1.provider))

    all_keys =
      configured_keys
      |> MapSet.union(canonical_keys)
      |> MapSet.union(integration_keys)

    all_keys
    |> Enum.map(fn key ->
      find_platform_metadata(key) || build_unknown_platform(key, Atom.to_string(key))
    end)
    |> Enum.sort_by(& &1.name)
  end

  defp find_platform_metadata(provider_key) do
    case Map.get(@platform_metadata, provider_key) do
      nil -> nil
      meta -> Map.put(meta, :key, provider_key)
    end
  end

  defp build_unknown_platform(provider_atom, provider_str) do
    %{key: provider_atom, name: provider_display_name(provider_str), description: ""}
  end

  # ---------------------------------------------------------------------------
  # Private helpers — utilities
  # ---------------------------------------------------------------------------

  defp platform_connected?(integrations, provider_key) do
    Enum.any?(integrations, fn i -> i.provider == provider_key end)
  end

  defp provider_display_name(provider) when is_binary(provider) do
    case Map.get(@platform_metadata, String.to_existing_atom(provider)) do
      %{name: name} -> name
      nil -> derive_display_name(provider)
    end
  rescue
    ArgumentError -> derive_display_name(provider)
  end

  defp derive_display_name(provider) do
    provider
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map_join(" ", &String.capitalize/1)
  end
end
