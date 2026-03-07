defmodule MetricFlowWeb.ActiveAccountHook do
  @moduledoc """
  LiveView on_mount hook that loads the active account name for the current scope.

  Assigns `active_account_name` to the socket so the navigation layout can
  display which account is currently active. Uses the first account returned
  by `Accounts.list_accounts/1`, which is the most recently created account
  (accounts are returned in descending order of insertion).
  """

  import Phoenix.Component, only: [assign: 3]

  alias MetricFlow.Accounts

  def on_mount(:load_active_account, _params, _session, socket) do
    scope = socket.assigns[:current_scope]

    active_account_name =
      if scope && scope.user do
        case Accounts.list_accounts(scope) do
          [account | _] -> account.name
          [] -> nil
        end
      end

    {:cont, assign(socket, :active_account_name, active_account_name)}
  end
end
