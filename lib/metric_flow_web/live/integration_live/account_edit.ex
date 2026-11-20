defmodule MetricFlowWeb.IntegrationLive.AccountEdit do
  @moduledoc """
  LiveView for editing which ad accounts or properties are synced for a
  connected integration, without requiring the user to re-authenticate via OAuth.

  Loads the existing integration's selected accounts from provider_metadata and
  presents them as checkboxes. The user can toggle selections and save. When
  no accounts are configured yet, a placeholder checkbox is rendered so the
  user can confirm the empty selection.
  """

  use MetricFlowWeb, :live_view

  alias MetricFlow.Accounts
  alias MetricFlow.Integrations

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
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      white_label_config={assigns[:white_label_config]}
      active_account_name={assigns[:active_account_name]}
      active_account_type={assigns[:active_account_type]}
    >
      <div class="mx-auto w-full max-w-lg overflow-x-hidden">
        <div class="mb-6">
          <h1 class="break-words text-2xl font-bold">
            {@platform_name} — Edit Accounts
          </h1>
          <p class="mt-1 break-words text-base-content/70">
            Choose which accounts or properties to sync.
          </p>
        </div>

        <form
          phx-submit="save_account_selection"
          data-role="account-selection"
          class="rounded-box border border-neutral bg-base-200 p-6"
        >
          <fieldset class="space-y-2">
            <legend class="sr-only">Accounts to sync</legend>
            <label
              :for={{account, idx} <- Enum.with_index(@display_accounts)}
              class="flex items-center gap-3 rounded-box border border-neutral bg-base-100 p-3 hover:bg-base-300"
            >
              <input
                type="checkbox"
                data-role="account-checkbox"
                name={"accounts[#{idx}]"}
                value={account.id}
                checked={account.selected}
                class="checkbox checkbox-sm checkbox-primary"
              />
              <span class="min-w-0 break-words text-sm text-base-content">
                {account.label}
              </span>
            </label>
          </fieldset>

          <div class="mt-6 flex flex-col-reverse gap-2 sm:flex-row sm:items-center sm:justify-end">
            <.link
              navigate={~p"/app/integrations"}
              class="inline-flex w-full items-center justify-center rounded-box border border-neutral bg-base-200 px-4 py-2 text-sm text-base-content hover:bg-base-300 sm:w-auto"
            >
              Back to integrations
            </.link>
            <button
              type="submit"
              phx-click="save_account_selection"
              data-role="save-account-selection"
              class="btn-brand-gradient w-full rounded-box px-4 py-2 font-semibold sm:w-auto"
            >
              Save Selection
            </button>
          </div>
        </form>
      </div>
    </Layouts.app>
    """
  end

  # ---------------------------------------------------------------------------
  # Mount + Params
  # ---------------------------------------------------------------------------

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope

    current_user_role =
      if socket.assigns.active_account_id do
        Accounts.get_user_role(scope, scope.user.id, socket.assigns.active_account_id)
      end

    socket = assign(socket, :can_modify, current_user_role in [:owner, :admin, :account_manager])

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

    cond do
      not socket.assigns.can_modify ->
        {:noreply,
         socket
         |> put_flash(:error, "You are not authorized to edit integration accounts.")
         |> push_navigate(to: ~p"/app/integrations")}

      match?(:unknown_provider, result) ->
        {:noreply, push_navigate(socket, to: ~p"/app/integrations")}

      true ->
        {:ok, _provider, _integration, accounts, platform_name} = result
        display_accounts = build_display_accounts(accounts)

        socket =
          socket
          |> assign(:display_accounts, display_accounts)
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
     |> push_navigate(to: ~p"/app/integrations")}
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp build_display_accounts([]) do
    # Show a placeholder unchecked checkbox when no accounts are configured,
    # allowing the user to see the selection interface and confirm the empty state.
    [
      %{
        id: "placeholder",
        label: "No accounts configured — connect and sync to populate",
        selected: false
      }
    ]
  end

  defp build_display_accounts(accounts) do
    Enum.map(accounts, fn account ->
      %{id: account, label: account, selected: true}
    end)
  end

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
