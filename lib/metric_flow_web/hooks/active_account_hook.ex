defmodule MetricFlowWeb.Hooks.ActiveAccountHook do
  @moduledoc """
  LiveView on_mount hook that loads the active account for the current scope.

  Puts the active account id on `current_scope` (so every account-scoped
  read and write in the LiveView acts on it) and assigns `active_account_id`,
  `active_account_name` and `active_account_type` so the navigation layout
  can display which account is currently active. The active account is
  `active_account/2`: the most recently switched-to account, else the most
  recently updated membership (the first of `Accounts.list_accounts/1`).
  """

  import Phoenix.Component, only: [assign: 3]

  alias MetricFlow.Accounts
  alias MetricFlow.Users.Scope

  def on_mount(:load_active_account, _params, _session, socket) do
    scope = socket.assigns[:current_scope]

    {active_account_id, active_account_name, active_account_type} =
      if scope && scope.user do
        accounts = Accounts.list_accounts(scope)
        account = active_account(accounts, scope.user)
        {account && account.id, account && account.name, account && account.type}
      else
        {nil, nil, nil}
      end

    socket =
      socket
      |> maybe_put_scope_account(scope, active_account_id)
      |> assign(:active_account_id, active_account_id)
      |> assign(:active_account_name, active_account_name)
      |> assign(:active_account_type, active_account_type)

    {:cont, socket}
  end

  # Every LiveView reads account-owned data (integrations, metrics,
  # dashboards...) through `current_scope`, so the active account rides on it.
  defp maybe_put_scope_account(socket, %Scope{} = scope, account_id) do
    assign(socket, :current_scope, Scope.put_account_id(scope, account_id))
  end

  defp maybe_put_scope_account(socket, _scope, _account_id), do: socket

  @doc """
  Returns `scope` carrying the active account id -- the same account this
  hook puts on LiveView sockets. For controllers (e.g. OAuth callbacks) that
  have no socket. A scope that already names an account is left as is.
  """
  @spec put_active_account(Scope.t() | nil) :: Scope.t() | nil
  def put_active_account(%Scope{user: user, account_id: nil} = scope) when not is_nil(user) do
    Scope.put_account_id(scope, MetricFlow.AccountAccess.default_account_id(user.id))
  end

  def put_active_account(scope), do: scope

  @doc """
  The active account among `accounts` (the user's memberships, as
  `Accounts.list_accounts/1` orders them): the one most recently switched
  to, else the most recently updated membership. Same answer as
  `MetricFlow.AccountAccess.default_account_id/1`, which non-LiveView code
  (controllers, contexts) uses.
  """
  def active_account([], _user), do: nil

  def active_account(accounts, _user), do: primary_account(accounts)

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
