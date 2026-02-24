defmodule MetricFlowWeb.IntegrationLive.Index do
  @moduledoc """
  LiveView for listing a user's connected integrations.

  Displays all configured platform integrations for the authenticated user
  with their current connection status. Provides navigation to connect
  new platforms or manage existing integrations.
  """

  use MetricFlowWeb, :live_view

  alias MetricFlow.Integrations

  # Static display metadata for known marketing platforms.
  @platform_metadata %{
    google_ads: %{name: "Google Ads", description: "Paid search and display advertising"},
    facebook_ads: %{name: "Facebook Ads", description: "Social media advertising"},
    google_analytics: %{name: "Google Analytics", description: "Web and app analytics"},
    google: %{name: "Google", description: "Google OAuth"}
  }

  # ---------------------------------------------------------------------------
  # Render
  # ---------------------------------------------------------------------------

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-3xl mf-content px-4 py-8">
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

        <div :if={@integrations == []} class="mf-card p-8 text-center">
          <p class="text-base-content/60 mb-4">
            No platforms connected yet.
          </p>
          <.link navigate={~p"/integrations/connect"} class="btn btn-primary">
            Connect your first platform
          </.link>
        </div>

        <div :if={@integrations != []} class="space-y-4 mb-8">
          <h2 class="text-lg font-semibold">Connected Platforms</h2>
          <div
            :for={platform <- @platforms}
            :if={not is_nil(find_integration(@integrations, platform.key))}
            data-role="integration-status"
            class="mf-card p-5 flex items-center justify-between"
          >
            <div>
              <h3 class="font-semibold">{platform.name}</h3>
              <p class="text-sm text-base-content/60">{platform.description}</p>
              <span class="badge badge-success mt-1">Connected</span>
            </div>
            <.link
              navigate={~p"/integrations/connect/#{platform.key}"}
              class="btn btn-ghost btn-sm"
            >
              Manage
            </.link>
          </div>
        </div>

        <div class="mt-4">
          <h2 class="text-lg font-semibold mb-4">Available Platforms</h2>
          <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
            <div
              :for={platform <- @platforms}
              :if={is_nil(find_integration(@integrations, platform.key))}
              data-role="platform-status"
              class="mf-card p-5"
            >
              <h3 class="font-semibold">{platform.name}</h3>
              <p class="text-sm text-base-content/60 mt-1">{platform.description}</p>
              <span class="badge badge-ghost mt-2">Not connected</span>
              <div class="mt-3">
                <.link
                  navigate={~p"/integrations/connect/#{platform.key}"}
                  class="btn btn-primary btn-sm w-full"
                >
                  Connect
                </.link>
              </div>
            </div>
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

    socket =
      socket
      |> assign(:integrations, integrations)
      |> assign(:platforms, platforms)

    {:ok, socket}
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp build_platform_list do
    Integrations.list_providers()
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

  defp find_integration(integrations, provider_key) do
    Enum.find(integrations, fn i -> i.provider == provider_key end)
  end

  defp derive_display_name(provider_str) do
    provider_str
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map_join(" ", &String.capitalize/1)
  end
end
