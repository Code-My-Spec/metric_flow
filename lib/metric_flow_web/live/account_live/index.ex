defmodule MetricFlowWeb.AccountLive.Index do
  @moduledoc """
  LiveView for listing accounts the current user belongs to.

  Displays all personal and team accounts for the authenticated user.
  Subscribes to account PubSub for real-time updates.
  """

  use MetricFlowWeb, :live_view

  alias MetricFlow.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-2xl">
        <.header>Your Accounts</.header>

        <div class="mt-8 space-y-4">
          <div :if={@accounts == []} class="text-base-content/60 text-sm">
            No accounts found.
          </div>
          <div
            :for={account <- @accounts}
            class="card bg-base-200 p-6"
          >
            <h3 class="text-lg font-semibold">{account.name}</h3>
            <div class="mt-2">
              <span class="badge badge-primary">Owner</span>
            </div>
            <div class="mt-2 text-sm text-base-content/70">
              Originator: {@current_scope.user.email}
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope
    accounts = Accounts.list_accounts(scope)

    if connected?(socket), do: Accounts.subscribe_account(scope)

    {:ok, assign(socket, :accounts, accounts)}
  end

  @impl true
  def handle_info({event, _account}, socket)
      when event in [:created, :updated, :deleted] do
    scope = socket.assigns.current_scope
    accounts = Accounts.list_accounts(scope)
    {:noreply, assign(socket, :accounts, accounts)}
  end
end
