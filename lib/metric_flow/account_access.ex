defmodule MetricFlow.AccountAccess do
  @moduledoc """
  Resolves which account a `%Scope{}` acts on and whether it may read or
  write that account's data.

  Integrations, sync jobs, sync history, metrics, derived metric definitions,
  dashboards and visualizations are owned by an account. Every member of the
  account can read them; members with an owner, admin or account_manager role
  can change them. Agency staff reach client accounts through ordinary
  AccountMember rows (created by agency access grants), so membership is the
  only check.

  Resolution rules for `account_id/1`:

    * `%Scope{user: nil, account_id: id}` -- a system scope built by a
      background job from an account-owned record. Trusted as is.
    * `%Scope{user: user, account_id: id}` -- `id` when `user` is a member of
      it, otherwise `nil` (no access).
    * `%Scope{user: user, account_id: nil}` -- the user's default account
      (`default_account_id/1`), the same one the account switcher and
      `MetricFlowWeb.Hooks.ActiveAccountHook` treat as active.

  These helpers live at the top-level boundary (and query `AccountMember`
  directly) because Accounts depends on Integrations, Metrics and Dashboards,
  which therefore cannot depend on Accounts.
  """

  import Ecto.Query

  alias MetricFlow.Accounts.AccountMember
  alias MetricFlow.Repo
  alias MetricFlow.Users.Scope

  @write_roles [:owner, :admin, :account_manager]

  @doc "Roles that may change an account's connections, data and reports."
  @spec write_roles() :: [atom()]
  def write_roles, do: @write_roles

  @doc """
  Returns the account id the scope acts on, or nil when it has no account
  (or is not a member of the one it names).
  """
  @spec account_id(Scope.t() | nil) :: integer() | nil
  def account_id(%Scope{user: nil, account_id: account_id}) when is_integer(account_id),
    do: account_id

  def account_id(%Scope{user: %{id: user_id}, account_id: account_id})
      when is_integer(account_id) do
    if member?(user_id, account_id), do: account_id, else: nil
  end

  def account_id(%Scope{user: %{id: user_id}, account_id: nil}), do: default_account_id(user_id)
  def account_id(_scope), do: nil

  @doc """
  Like `account_id/1`, but returns `{:ok, id}` or `{:error, :no_account}`.
  """
  @spec fetch_account_id(Scope.t()) :: {:ok, integer()} | {:error, :no_account}
  def fetch_account_id(scope) do
    case account_id(scope) do
      nil -> {:error, :no_account}
      id -> {:ok, id}
    end
  end

  @doc """
  Returns `scope` with its account id resolved (see `account_id/1`). Leaves
  the scope unchanged when no account can be resolved.
  """
  @spec resolve(Scope.t()) :: Scope.t()
  def resolve(%Scope{} = scope) do
    case account_id(scope) do
      nil -> scope
      id -> %{scope | account_id: id}
    end
  end

  @doc """
  Restricts `query` (whose first binding has an `account_id` field) to the
  scope's account. When the scope has no accessible account the query
  matches nothing.
  """
  @spec scope_query(Ecto.Queryable.t(), Scope.t()) :: Ecto.Query.t()
  def scope_query(query, %Scope{} = scope) do
    case account_id(scope) do
      nil -> where(query, false)
      account_id -> where(query, [r], r.account_id == ^account_id)
    end
  end

  @doc """
  Checks whether the scope may change its account's data. System scopes
  (no user) are always allowed.
  """
  @spec authorize_write(Scope.t()) :: {:ok, integer()} | {:error, :unauthorized}
  def authorize_write(%Scope{user: nil, account_id: account_id}) when is_integer(account_id),
    do: {:ok, account_id}

  def authorize_write(%Scope{user: %{id: user_id}} = scope) do
    with account_id when is_integer(account_id) <- account_id(scope),
         true <- writer?(user_id, account_id) do
      {:ok, account_id}
    else
      _ -> {:error, :unauthorized}
    end
  end

  def authorize_write(_scope), do: {:error, :unauthorized}

  @doc "True when the scope may change its account's data."
  @spec can_write?(Scope.t()) :: boolean()
  def can_write?(scope), do: match?({:ok, _}, authorize_write(scope))

  @doc "The user id to record as creator/connector, or nil for system scopes."
  @spec user_id(Scope.t()) :: integer() | nil
  def user_id(%Scope{user: %{id: id}}), do: id
  def user_id(_scope), do: nil

  @doc """
  The user's active account when nothing else says which: the account they
  most recently switched to (`Accounts.touch_membership/2`), else their most
  recently updated membership -- the first of `Accounts.list_accounts/1`.
  This is the one resolver behind the account switcher's default, every
  LiveView's scope (`MetricFlowWeb.Hooks.ActiveAccountHook`) and the OAuth
  callbacks.
  """
  @spec default_account_id(integer()) :: integer() | nil
  def default_account_id(user_id) do
    from(m in AccountMember,
      where: m.user_id == ^user_id,
      order_by: [desc_nulls_last: m.last_active_at, desc: m.updated_at, desc: m.id],
      select: m.account_id,
      limit: 1
    )
    |> Repo.one()
  end

  @doc "True when the user is a member of the account."
  @spec member?(integer(), integer()) :: boolean()
  def member?(user_id, account_id) do
    from(m in AccountMember, where: m.user_id == ^user_id and m.account_id == ^account_id)
    |> Repo.exists?()
  end

  @doc """
  Every account the user is a member of (own accounts and agency client
  accounts alike), as `%{id, name, type, role}`, ordered by name.
  """
  @spec memberships(integer()) :: [map()]
  def memberships(user_id) do
    from(m in AccountMember,
      join: a in assoc(m, :account),
      where: m.user_id == ^user_id,
      order_by: [asc: a.name, asc: a.id],
      select: %{id: a.id, name: a.name, type: a.type, role: m.role}
    )
    |> Repo.all()
  end

  @doc "True when the user holds a write role in the account."
  @spec writer?(integer(), integer()) :: boolean()
  def writer?(user_id, account_id) do
    from(m in AccountMember,
      where: m.user_id == ^user_id and m.account_id == ^account_id and m.role in ^@write_roles
    )
    |> Repo.exists?()
  end

  @doc "Emails of the account's owners and admins (for operational notices)."
  @spec admin_emails(integer()) :: [String.t()]
  def admin_emails(account_id) do
    from(m in AccountMember,
      join: u in assoc(m, :user),
      where: m.account_id == ^account_id and m.role in [:owner, :admin],
      order_by: [asc: m.id],
      select: u.email
    )
    |> Repo.all()
  end

  @doc "PubSub topic for an account's sync lifecycle events."
  @spec sync_topic(integer()) :: String.t()
  def sync_topic(account_id), do: "account:#{account_id}:sync"

  @doc "PubSub topic for an account's correlation job updates."
  @spec correlations_topic(integer()) :: String.t()
  def correlations_topic(account_id), do: "account:#{account_id}:correlations"
end
