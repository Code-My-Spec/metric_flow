defmodule MetricFlowWeb.Hooks.ActiveAccountHook do
  @moduledoc """
  LiveView on_mount hook that loads the active account name for the current scope.

  Assigns `active_account_name` to the socket so the navigation layout can
  display which account is currently active. Uses the first account returned
  by `Accounts.list_accounts/1`, which is the most recently switched-to account
  (accounts are returned in descending order of membership `updated_at`).
  """

  import Phoenix.Component, only: [assign: 3]

  alias MetricFlow.Accounts

  def on_mount(:load_active_account, _params, _session, socket) do
    scope = socket.assigns[:current_scope]

    {active_account_id, active_account_name} =
      if scope && scope.user do
        accounts = Accounts.list_accounts(scope)
        account = primary_account(accounts)
        {account && account.id, account && account.name}
      else
        {nil, nil}
      end

    socket =
      socket
      |> assign(:active_account_id, active_account_id)
      |> assign(:active_account_name, active_account_name)

    {:cont, socket}
  end

  @doc false
  def primary_account(accounts) do
    # First account is the most recently switched-to (ordered by updated_at DESC).
    # However, we prefer an account the user originated (their own account) over
    # client accounts they were granted access to, as a sensible default.
    List.first(accounts)
  end

  @doc """
  Like `primary_account/1` but given the user, prefers the account they
  originated (created). Falls back to the first account in the list.
  """
  def primary_account(accounts, user) do
    Enum.find(accounts, fn a -> a.originator_user_id == user.id end) ||
      List.first(accounts)
  end
end
