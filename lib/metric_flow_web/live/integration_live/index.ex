defmodule MetricFlowWeb.IntegrationLive.Index do
  @moduledoc """
  LiveView for listing a user's connected integrations.

  Displays all configured platform integrations for the authenticated user
  with their current connection status, including both marketing and financial
  platforms. Provides navigation to connect new platforms or manage existing
  integrations. Supports manual sync triggering with inline sync status
  feedback.
  """

  use MetricFlowWeb, :live_view

  alias MetricFlow.DataSync
  alias MetricFlow.Integrations

  # Data platforms — each has its own OAuth provider and integration record.
  @data_platforms [
    %{key: :google_analytics, name: "Google Analytics", description: "Website traffic and user behavior analytics", provider: :google_analytics},
    %{key: :google_ads, name: "Google Ads", description: "Paid search and display advertising", provider: :google_ads},
    %{key: :google_search_console, name: "Google Search Console", description: "Search performance and indexing data", provider: :google_search_console},
    %{key: :facebook_ads, name: "Facebook Ads", description: "Social media advertising", provider: :facebook_ads},
    %{key: :quickbooks, name: "QuickBooks", description: "Accounting and financial data", provider: :quickbooks}
  ]

  # Provider display names for messages.
  @provider_names %{
    google_analytics: "Google Analytics",
    google_ads: "Google Ads",
    google_search_console: "Google Search Console",
    facebook_ads: "Facebook",
    quickbooks: "QuickBooks"
  }

  # ---------------------------------------------------------------------------
  # Render
  # ---------------------------------------------------------------------------

  @impl true
  def render(assigns) do
    # Split platforms into connected (parent provider exists) and not connected
    assigns =
      assigns
      |> assign(
        :connected_platforms,
        Enum.filter(assigns.platforms, fn p -> provider_connected?(p.provider, assigns.integrations) end)
      )
      |> assign(
        :unconnected_platforms,
        Enum.reject(assigns.platforms, fn p -> provider_connected?(p.provider, assigns.integrations) end)
      )

    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active_account_name={@active_account_name}>
      <div class="mx-auto max-w-3xl mf-content px-4 py-8" data-role="integrations-index">
        <div class="mb-8 flex items-center justify-between">
          <div>
            <h1 class="text-2xl font-bold">Integrations</h1>
            <p class="mt-1 text-base-content/60">
              Manage your connected marketing platforms
            </p>
          </div>
          <.link navigate={~p"/integrations/connect"} class="btn btn-primary btn-sm">
            Connect a Platform
          </.link>
        </div>

        <%= if @integrations == [] do %>
          <div class="text-center py-12">
            <p class="text-base-content/60">No platforms connected yet.</p>
            <.link navigate={~p"/integrations/connect"} class="btn btn-primary btn-sm mt-4">
              Connect your first platform
            </.link>
          </div>
        <% end %>

        <%= if @connected_platforms != [] do %>
          <div class="mb-8">
            <h2 class="text-lg font-semibold mb-4">Connected Platforms</h2>
            <div data-role="integrations-list" class="space-y-4">
              <div
                :for={platform <- @connected_platforms}
                data-role="integration-card"
                data-platform={Atom.to_string(platform.key)}
                data-status="connected"
                class="mf-card p-5"
              >
                <div data-role="integration-row" class="flex items-start justify-between">
                  <div class="flex-1">
                    <h3 data-role="integration-platform-name" class="font-semibold">
                      {platform.name}
                    </h3>
                    <p class="text-sm text-base-content/60">{platform.description}</p>

                    <div class="mt-1 flex flex-wrap items-center gap-2">
                      <span data-status="connected" class="badge badge-success">Connected</span>
                      <span data-role="integration-sync-status" class="flex items-center gap-1">
                        <%= if MapSet.member?(@syncing, platform.key) do %>
                          <span class="badge badge-warning">
                            Syncing
                            <span class="loading loading-spinner loading-xs ml-1"></span>
                          </span>
                        <% else %>
                          <%= if result = Map.get(@sync_results, platform.key) do %>
                            <span class="badge badge-success text-xs">
                              Synced {result.records_synced} records at {Calendar.strftime(result.completed_at, "%Y-%m-%d %H:%M")} UTC
                            </span>
                          <% end %>
                        <% end %>
                      </span>
                    </div>

                    <% integration = find_integration(@integrations, platform.provider) %>
                    <%= if integration do %>
                      <p data-role="integration-connected-date" class="text-xs text-base-content/50 mt-1">
                        Connected via {provider_display_name(platform.provider)} on {Calendar.strftime(integration.inserted_at, "%Y-%m-%d")}
                      </p>
                      <div data-role="integration-selected-accounts" class="mt-2 text-sm text-base-content/60">
                        <% account_value = selected_account_display(integration) %>
                        <%= if account_value do %>
                          <span class="text-xs">{account_value}</span>
                        <% else %>
                          <span class="text-xs italic">No accounts selected</span>
                        <% end %>
                      </div>
                    <% end %>
                  </div>

                  <div class="flex flex-col items-end gap-2 ml-4">
                    <button
                      phx-click="sync"
                      phx-value-platform={Atom.to_string(platform.key)}
                      phx-value-provider={Atom.to_string(platform.provider)}
                      phx-disable-with="Please wait..."
                      disabled={MapSet.member?(@syncing, platform.key)}
                      class="btn btn-outline btn-sm"
                    >
                      Sync Now
                    </button>
                    <.link
                      data-role="edit-integration-accounts"
                      navigate={~p"/integrations/connect/#{Atom.to_string(platform.provider)}/accounts"}
                      class="btn btn-ghost btn-sm"
                    >
                      Edit Accounts
                    </.link>
                    <.link
                      data-role="integration-detail-link"
                      navigate={~p"/integrations/connect/#{Atom.to_string(platform.provider)}"}
                      class="btn btn-ghost btn-xs"
                    >
                      Manage
                    </.link>
                    <button
                      data-role="disconnect-integration"
                      phx-click="confirm_disconnect"
                      phx-value-provider={Atom.to_string(platform.provider)}
                      class="btn btn-ghost btn-xs text-error"
                    >
                      Disconnect
                    </button>
                  </div>
                </div>

              </div>
            </div>
          </div>
        <% end %>

        <%= if @unconnected_platforms != [] do %>
          <div>
            <h2 class="text-lg font-semibold mb-4">Available Platforms</h2>
            <div data-role="available-platforms-list" class="space-y-4">
              <div
                :for={platform <- @unconnected_platforms}
                data-role="integration-card"
                data-platform={Atom.to_string(platform.key)}
                data-status="available"
                class="mf-card p-5"
              >
                <div data-role="integration-row" class="flex items-start justify-between">
                  <div class="flex-1">
                    <h3 data-role="integration-platform-name" class="font-semibold">
                      {platform.name}
                    </h3>
                    <p class="text-sm text-base-content/60">{platform.description}</p>

                    <div class="mt-1 flex flex-wrap items-center gap-2">
                      <span data-role="integration-sync-status" class="badge badge-ghost">
                        Not connected
                      </span>
                    </div>

                    <p class="text-xs text-base-content/40 mt-1 italic">
                      Connect {provider_display_name(platform.provider)} first
                    </p>
                  </div>

                  <div class="flex flex-col items-end gap-2 ml-4">
                    <.link
                      data-role="reconnect-integration"
                      navigate={~p"/integrations/connect"}
                      class="btn btn-primary btn-sm"
                    >
                      Connect {provider_display_name(platform.provider)}
                    </.link>
                  </div>
                </div>
              </div>
            </div>
          </div>
        <% end %>
        <%= if @disconnecting do %>
          <% disc_provider_name = provider_display_name(@disconnecting) %>
          <dialog
            class="modal modal-open"
            data-role="disconnect-modal"
          >
            <div class="modal-box">
              <h3 class="font-bold text-lg">Disconnect {disc_provider_name}?</h3>
              <p class="py-4" data-role="disconnect-warning">
                Are you sure you want to disconnect <strong>{disc_provider_name}</strong>?
                This will affect all platforms that use this connection.
                Historical data will remain available, but no new data will sync after disconnecting.
              </p>
              <div class="modal-action">
                <button
                  data-role="cancel-disconnect"
                  phx-click="cancel_disconnect"
                  class="btn"
                >
                  Cancel
                </button>
                <button
                  data-role="confirm-disconnect"
                  phx-click="disconnect"
                  phx-value-provider={Atom.to_string(@disconnecting)}
                  class="btn btn-error"
                >
                  Disconnect
                </button>
              </div>
            </div>
            <form method="dialog" class="modal-backdrop">
              <button phx-click="cancel_disconnect">close</button>
            </form>
          </dialog>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  # ---------------------------------------------------------------------------
  # Mount
  # ---------------------------------------------------------------------------

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope
    integrations = Integrations.list_integrations(scope)

    if Phoenix.LiveView.connected?(socket) do
      Phoenix.PubSub.subscribe(MetricFlow.PubSub, "user:#{scope.user.id}:sync")
    end

    socket =
      socket
      |> assign(:integrations, integrations)
      |> assign(:platforms, @data_platforms)
      |> assign(:syncing, MapSet.new())
      |> assign(:sync_results, %{})
      |> assign(:disconnecting, nil)

    {:ok, socket}
  end

  # ---------------------------------------------------------------------------
  # Event handlers
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("sync", %{"platform" => platform_str, "provider" => provider_str}, socket) do
    platform_key = String.to_existing_atom(platform_str)
    provider = String.to_existing_atom(provider_str)
    scope = socket.assigns.current_scope
    platform_name = find_platform_name(platform_key)

    case DataSync.sync_integration(scope, provider) do
      {:ok, _sync_job} ->
        socket =
          socket
          |> assign(:syncing, MapSet.put(socket.assigns.syncing, platform_key))
          |> put_flash(:info, "Sync started for #{platform_name}")

        {:noreply, socket}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "#{platform_name} integration not found. Please connect it first.")}

      {:error, :not_connected} ->
        {:noreply, put_flash(socket, :error, "#{platform_name} token has expired. Please reconnect.")}

      {:error, reason} ->
        require Logger
        Logger.error("Sync failed for #{platform_name}: #{inspect(reason)}")
        {:noreply, put_flash(socket, :error, "Failed to start sync for #{platform_name}: #{inspect(reason)}")}
    end
  end

  # Fallback for legacy sync events that only pass provider
  def handle_event("sync", %{"provider" => provider_str}, socket) do
    provider = String.to_existing_atom(provider_str)
    scope = socket.assigns.current_scope
    platform_name = find_platform_name(provider)

    case DataSync.sync_integration(scope, provider) do
      {:ok, _sync_job} ->
        socket =
          socket
          |> assign(:syncing, MapSet.put(socket.assigns.syncing, provider))
          |> put_flash(:info, "Sync started for #{platform_name}")

        {:noreply, socket}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Integration not found.")}
    end
  end

  @impl true
  def handle_event("confirm_disconnect", %{"provider" => provider_str}, socket) do
    provider = String.to_existing_atom(provider_str)
    {:noreply, assign(socket, :disconnecting, provider)}
  end

  @impl true
  def handle_event("cancel_disconnect", _params, socket) do
    {:noreply, assign(socket, :disconnecting, nil)}
  end

  @impl true
  def handle_event("disconnect", %{"provider" => provider_str}, socket) do
    provider = String.to_existing_atom(provider_str)
    scope = socket.assigns.current_scope

    case Integrations.disconnect(scope, provider) do
      {:ok, _} ->
        integrations = Integrations.list_integrations(scope)

        socket =
          socket
          |> assign(:integrations, integrations)
          |> assign(:disconnecting, nil)
          |> put_flash(
            :info,
            "Disconnected from #{provider_display_name(provider)}. Historical data is retained; no new data will sync after disconnecting."
          )

        {:noreply, socket}

      {:error, _} ->
        socket =
          socket
          |> assign(:disconnecting, nil)
          |> put_flash(:error, "Failed to disconnect integration.")

        {:noreply, socket}
    end
  end

  # ---------------------------------------------------------------------------
  # Message handlers (async sync completion)
  # ---------------------------------------------------------------------------

  @impl true
  def handle_info(
        {:sync_completed, %{provider: provider, records_synced: count, completed_at: completed_at}},
        socket
      ) do
    result = %{records_synced: count, completed_at: completed_at}

    # Store result under each platform key that maps to this provider,
    # since the template looks up by platform key (e.g. :google_analytics),
    # not by OAuth provider (e.g. :google).
    platform_keys = platform_keys_for_provider(provider)

    sync_results =
      Enum.reduce(platform_keys, socket.assigns.sync_results, fn key, acc ->
        Map.put(acc, key, result)
      end)

    syncing =
      socket.assigns.syncing
      |> MapSet.delete(provider)
      |> remove_platform_keys_for_provider(provider)

    socket =
      socket
      |> assign(:syncing, syncing)
      |> assign(:sync_results, sync_results)

    {:noreply, socket}
  end

  def handle_info(
        {:sync_failed, %{provider: provider, reason: reason}},
        socket
      ) do
    syncing =
      socket.assigns.syncing
      |> MapSet.delete(provider)
      |> remove_platform_keys_for_provider(provider)

    socket =
      socket
      |> assign(:syncing, syncing)
      |> put_flash(:error, build_failure_message(provider, reason))

    {:noreply, socket}
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp build_failure_message(provider, reason) when is_binary(reason) and reason != "" do
    "Sync failed for #{provider_display_name(provider)}: #{reason}"
  end

  defp build_failure_message(provider, _reason) do
    "Sync failed for #{provider_display_name(provider)}. Please check your connection and try again."
  end

  defp platform_keys_for_provider(provider) do
    @data_platforms
    |> Enum.filter(&(&1.provider == provider))
    |> Enum.map(& &1.key)
  end

  defp remove_platform_keys_for_provider(syncing, provider) do
    @data_platforms
    |> Enum.filter(&(&1.provider == provider))
    |> Enum.reduce(syncing, fn p, acc -> MapSet.delete(acc, p.key) end)
  end

  defp find_integration(integrations, provider_key) do
    Enum.find(integrations, fn i -> i.provider == provider_key end)
  end

  defp provider_connected?(provider_key, integrations) do
    Enum.any?(integrations, fn i -> i.provider == provider_key end)
  end

  defp find_platform_name(platform_key) do
    case Enum.find(@data_platforms, fn p -> p.key == platform_key end) do
      nil -> platform_key |> Atom.to_string() |> derive_display_name()
      platform -> platform.name
    end
  end

  defp provider_display_name(provider_key) do
    Map.get(@provider_names, provider_key, provider_key |> Atom.to_string() |> derive_display_name())
  end

  defp derive_display_name(provider_str) do
    provider_str
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  # Looks up the selected account value from provider_metadata using the correct key per provider.
  defp selected_account_display(%{provider: provider, provider_metadata: meta}) when is_map(meta) do
    key = metadata_key_for_provider(provider)
    value = Map.get(meta, key)

    cond do
      is_binary(value) and value != "" ->
        value

      # Fallback: old integrations may have saved under "property_id"
      is_binary(Map.get(meta, "property_id")) and Map.get(meta, "property_id") != "" ->
        Map.get(meta, "property_id")

      is_list(Map.get(meta, "selected_accounts")) ->
        Enum.join(Map.get(meta, "selected_accounts"), ", ")

      true ->
        nil
    end
  end

  defp selected_account_display(_), do: nil

  defp metadata_key_for_provider(:google_analytics), do: "property_id"
  defp metadata_key_for_provider(:google_ads), do: "customer_id"
  defp metadata_key_for_provider(:google_search_console), do: "site_url"
  defp metadata_key_for_provider(:quickbooks), do: "realm_id"
  defp metadata_key_for_provider(:facebook_ads), do: "ad_account_id"
  defp metadata_key_for_provider(_), do: "property_id"
end
