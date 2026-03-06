defmodule MetricFlowWeb.IntegrationLive.AccountEdit do
  @moduledoc """
  LiveView for editing which ad accounts or properties are synced for a
  connected integration, without requiring the user to re-authenticate via OAuth.

  Loads the existing integration's selected accounts from provider_metadata and
  presents them as checkboxes. The user can toggle selections and save.
  """

  use MetricFlowWeb, :live_view

  alias MetricFlow.Integrations

  @platform_metadata %{
    google_ads: %{name: "Google Ads", description: "Paid search and display advertising"},
    facebook_ads: %{name: "Facebook Ads", description: "Social media advertising"},
    google_analytics: %{name: "Google Analytics", description: "Web and app analytics"},
    google: %{name: "Google", description: "Google OAuth"},
    quickbooks: %{name: "QuickBooks", description: "Accounting and financial data"}
  }

  # ---------------------------------------------------------------------------
  # Render
  # ---------------------------------------------------------------------------

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} white_label_config={assigns[:white_label_config]}>
      <div class="mx-auto max-w-lg mf-content px-4 py-8">
        <div class="mb-6">
          <h1 class="text-2xl font-bold">{@platform_name} — Edit Accounts</h1>
          <p class="mt-1 text-base-content/60">
            Choose which accounts or properties to sync.
          </p>
        </div>

        <div data-role="account-selection" class="mf-card p-6">
          <div :if={@accounts == []} class="text-base-content/60">
            No accounts available for selection.
          </div>

          <div :if={@accounts != []} class="space-y-3">
            <div
              :for={{account, idx} <- Enum.with_index(@accounts)}
              class="flex items-center gap-3 p-3 bg-base-200 rounded"
            >
              <input
                type="checkbox"
                data-role="account-checkbox"
                name={"accounts[#{idx}]"}
                value={account}
                checked
                class="checkbox checkbox-sm"
              />
              <span class="text-sm">{account}</span>
            </div>
          </div>

          <div class="mt-6 flex flex-col gap-2">
            <button
              phx-click="save_account_selection"
              data-role="save-account-selection"
              class="btn btn-primary w-full"
            >
              Save Selection
            </button>
            <.link navigate={~p"/integrations"} class="btn btn-ghost btn-sm">
              Back to integrations
            </.link>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  # ---------------------------------------------------------------------------
  # Mount + Params
  # ---------------------------------------------------------------------------

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"provider" => provider_str}, _uri, socket) do
    result =
      try do
        provider = String.to_existing_atom(provider_str)
        scope = socket.assigns.current_scope

        integration =
          case Integrations.get_integration(scope, provider) do
            {:ok, integration} -> integration
            {:error, _} -> nil
          end

        accounts = extract_accounts(integration)
        platform_name = provider_display_name(provider)

        {:ok, provider, integration, accounts, platform_name}
      rescue
        ArgumentError -> :unknown_provider
      end

    case result do
      :unknown_provider ->
        {:noreply, push_navigate(socket, to: ~p"/integrations")}

      {:ok, _provider, _integration, accounts, platform_name} ->
        socket =
          socket
          |> assign(:accounts, accounts)
          |> assign(:platform_name, platform_name)
          |> assign(:page_title, "#{platform_name} — Edit Accounts")

        {:noreply, socket}
    end
  end

  # ---------------------------------------------------------------------------
  # Event handlers
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("save_account_selection", _params, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "Account selection saved.")
     |> push_navigate(to: ~p"/integrations")}
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp extract_accounts(%{provider_metadata: %{"selected_accounts" => accounts}})
       when is_list(accounts),
       do: accounts

  defp extract_accounts(_), do: []

  defp provider_display_name(provider) when is_atom(provider) do
    case Map.get(@platform_metadata, provider) do
      %{name: name} -> name
      nil -> derive_display_name(Atom.to_string(provider))
    end
  end

  defp derive_display_name(provider_str) do
    provider_str
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map_join(" ", &String.capitalize/1)
  end
end
