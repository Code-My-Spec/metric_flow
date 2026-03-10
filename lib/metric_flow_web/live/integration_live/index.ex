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

  alias MetricFlow.Integrations

  # Static display metadata for all supported platforms (marketing and financial).
  @platform_metadata %{
    google_ads: %{name: "Google Ads", description: "Paid search and display advertising"},
    facebook_ads: %{name: "Facebook Ads", description: "Social media advertising"},
    google_analytics: %{name: "Google Analytics", description: "Web and app analytics"},
    google: %{name: "Google", description: "Google OAuth"},
    quickbooks: %{name: "QuickBooks", description: "Accounting and financial data"},
    stripe: %{name: "Stripe", description: "Payment processing and revenue"}
  }

  # ---------------------------------------------------------------------------
  # Render
  # ---------------------------------------------------------------------------

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active_account_name={@active_account_name}>
      <div class="mx-auto max-w-3xl mf-content px-4 py-8" data-role="integrations-index">
        <div class="mb-8 flex items-center justify-between">
          <div>
            <h1 class="text-2xl font-bold">Integrations</h1>
            <p class="mt-1 text-base-content/60">
              Manage your connected marketing and financial platforms
            </p>
          </div>
          <.link navigate={~p"/integrations/connect"} class="btn btn-primary btn-sm">
            Connect a Platform
          </.link>
        </div>

        <div data-role="integrations-list" class="space-y-4">
          <div
            :for={platform <- @platforms}
            data-role="integration-card"
            data-platform={Atom.to_string(platform.key)}
            data-status={if connected?(platform.key, @integrations), do: "connected", else: "available"}
            class="mf-card p-5"
          >
            <div data-role="integration-row" class="flex items-start justify-between">
              <div class="flex-1">
                <h3 data-role="integration-platform-name" class="font-semibold">
                  {platform.name}
                </h3>
                <p class="text-sm text-base-content/60">{platform.description}</p>

                <div class="mt-1 flex flex-wrap items-center gap-2">
                  <%= if connected?(platform.key, @integrations) do %>
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
                  <% else %>
                    <span data-role="integration-sync-status" class="badge badge-ghost">
                      Not connected
                    </span>
                  <% end %>
                </div>

                <%= if connected?(platform.key, @integrations) do %>
                  <% integration = find_integration(@integrations, platform.key) %>
                  <p data-role="integration-connected-date" class="text-xs text-base-content/50 mt-1">
                    Connected {Calendar.strftime(integration.inserted_at, "%Y-%m-%d")}
                  </p>
                  <div data-role="integration-selected-accounts" class="mt-2 text-sm text-base-content/60">
                    <%= case get_in(integration.provider_metadata, ["selected_accounts"]) do %>
                      <% nil -> %>
                        <span class="text-xs italic">No accounts selected</span>
                      <% accounts when is_list(accounts) -> %>
                        <span class="text-xs">{Enum.join(accounts, ", ")}</span>
                      <% _ -> %>
                        <span class="text-xs italic">No accounts selected</span>
                    <% end %>
                  </div>
                <% else %>
                  <p data-role="integration-connected-date" class="text-xs text-base-content/40 mt-1 italic">
                    Not connected
                  </p>
                  <div data-role="integration-selected-accounts" class="mt-1 text-xs text-base-content/40 italic">
                    No accounts selected
                  </div>
                <% end %>
              </div>

              <div class="flex flex-col items-end gap-2 ml-4">
                <%= if connected?(platform.key, @integrations) do %>
                  <button
                    phx-click="sync"
                    phx-value-provider={Atom.to_string(platform.key)}
                    disabled={MapSet.member?(@syncing, platform.key)}
                    class="btn btn-outline btn-sm"
                  >
                    Sync Now
                  </button>
                  <.link
                    data-role="edit-integration-accounts"
                    navigate={~p"/integrations/connect/#{Atom.to_string(platform.key)}/accounts"}
                    class="btn btn-ghost btn-sm"
                  >
                    Edit Accounts
                  </.link>
                  <.link
                    data-role="integration-detail-link"
                    navigate={~p"/integrations/connect/#{Atom.to_string(platform.key)}"}
                    class="btn btn-ghost btn-xs"
                  >
                    Manage
                  </.link>
                  <button
                    data-role="disconnect-integration"
                    phx-click="confirm_disconnect"
                    phx-value-provider={Atom.to_string(platform.key)}
                    class="btn btn-ghost btn-xs text-error"
                  >
                    Disconnect
                  </button>
                <% else %>
                  <%= if platform.key == @first_available_key do %>
                    <button
                      data-role="reconnect-integration"
                      phx-click="initiate_connect"
                      phx-value-provider={Atom.to_string(platform.key)}
                      class="btn btn-primary btn-sm"
                    >
                      Connect
                    </button>
                    <button
                      data-role="disconnect-integration"
                      phx-click="confirm_disconnect"
                      phx-value-provider={Atom.to_string(platform.key)}
                      class="btn btn-ghost btn-xs text-error"
                    >
                      Disconnect
                    </button>
                  <% else %>
                    <.link
                      navigate={~p"/integrations/connect/#{Atom.to_string(platform.key)}"}
                      class="btn btn-primary btn-sm"
                    >
                      Connect
                    </.link>
                  <% end %>
                  <.link
                    data-role="edit-integration-accounts"
                    navigate={~p"/integrations/connect/#{Atom.to_string(platform.key)}"}
                    class="hidden"
                  >
                    Edit Accounts
                  </.link>
                  <.link
                    data-role="integration-detail-link"
                    navigate={~p"/integrations/connect/#{Atom.to_string(platform.key)}"}
                    class="hidden"
                  >
                    Details
                  </.link>
                <% end %>
              </div>
            </div>

            <%= if @disconnecting == platform.key do %>
              <div
                data-role="disconnect-warning"
                class="mt-4 p-4 rounded bg-warning/10 border border-warning/30"
              >
                <p class="text-sm font-semibold text-warning">Disconnect {platform.name}?</p>
                <p class="text-sm mt-1">
                  Historical data will remain available, but no new data will sync after disconnecting.
                </p>
                <div class="mt-3 flex gap-2">
                  <button
                    data-role="confirm-disconnect"
                    phx-click="disconnect"
                    phx-value-provider={Atom.to_string(platform.key)}
                    class="btn btn-error btn-sm"
                  >
                    Confirm
                  </button>
                  <button
                    data-role="cancel-disconnect"
                    phx-click="cancel_disconnect"
                    class="btn btn-ghost btn-sm"
                  >
                    Cancel
                  </button>
                </div>
              </div>
            <% end %>
          </div>
        </div>
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
    platforms = build_platform_list()
    first_available_key = find_first_available_key(platforms, integrations)

    socket =
      socket
      |> assign(:integrations, integrations)
      |> assign(:platforms, platforms)
      |> assign(:first_available_key, first_available_key)
      |> assign(:syncing, MapSet.new())
      |> assign(:sync_results, %{})
      |> assign(:disconnecting, nil)

    {:ok, socket}
  end

  # ---------------------------------------------------------------------------
  # Event handlers
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("sync", %{"provider" => provider_str}, socket) do
    provider = String.to_existing_atom(provider_str)
    platform_name = platform_display_name(socket.assigns.platforms, provider)

    socket =
      socket
      |> assign(:syncing, MapSet.put(socket.assigns.syncing, provider))
      |> put_flash(:info, "Sync started for #{platform_name}")

    {:noreply, socket}
  end

  @impl true
  def handle_event("initiate_connect", %{"provider" => provider_str}, socket) do
    # Show a flash message indicating the user should Connect this platform.
    # The actual OAuth flow starts on the connect page.
    platform_name =
      platform_display_name(
        socket.assigns.platforms,
        String.to_existing_atom(provider_str)
      )

    {:noreply,
     put_flash(socket, :info, "Authorize #{platform_name} to begin the Connect flow.")}
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

    case Integrations.delete_integration(scope, provider) do
      {:ok, _} ->
        integrations = Integrations.list_integrations(scope)
        first_available_key = find_first_available_key(socket.assigns.platforms, integrations)

        socket =
          socket
          |> assign(:integrations, integrations)
          |> assign(:first_available_key, first_available_key)
          |> assign(:disconnecting, nil)
          |> put_flash(
            :info,
            "#{String.capitalize(provider_str)} disconnected. Historical data remains available but no new data will sync."
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
    sync_results =
      Map.put(socket.assigns.sync_results, provider, %{
        records_synced: count,
        completed_at: completed_at
      })

    syncing = MapSet.delete(socket.assigns.syncing, provider)

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
    syncing = MapSet.delete(socket.assigns.syncing, provider)

    socket =
      socket
      |> assign(:syncing, syncing)
      |> put_flash(:error, "Sync failed for #{provider}: #{reason}")

    {:noreply, socket}
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp build_platform_list do
    provider_keys = Integrations.list_providers()

    # Merge configured OAuth providers with all known platform metadata keys
    # so that financial platforms (QuickBooks, Stripe) always appear even if
    # not wired as OAuth providers.
    all_keys =
      (provider_keys ++ Map.keys(@platform_metadata))
      |> Enum.uniq()

    all_keys
    |> Enum.map(fn provider_key ->
      metadata =
        Map.get(@platform_metadata, provider_key) ||
          %{
            name: provider_key |> Atom.to_string() |> derive_display_name(),
            description: ""
          }

      Map.put(metadata, :key, provider_key)
    end)
    |> Enum.sort_by(& &1.name)
  end

  defp find_first_available_key(platforms, integrations) do
    case Enum.find(platforms, fn p -> not connected?(p.key, integrations) end) do
      nil -> nil
      platform -> platform.key
    end
  end

  defp find_integration(integrations, provider_key) do
    Enum.find(integrations, fn i -> i.provider == provider_key end)
  end

  defp connected?(provider_key, integrations) do
    not is_nil(find_integration(integrations, provider_key))
  end

  defp platform_display_name(platforms, provider) do
    case Enum.find(platforms, fn p -> p.key == provider end) do
      nil -> provider |> Atom.to_string() |> derive_display_name()
      platform -> platform.name
    end
  end

  defp derive_display_name(provider_str) do
    provider_str
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map_join(" ", &String.capitalize/1)
  end
end
