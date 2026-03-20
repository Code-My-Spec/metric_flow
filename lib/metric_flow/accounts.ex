defmodule MetricFlow.Accounts do
  @moduledoc """
  Business accounts and membership management.

  Public API boundary for the Accounts bounded context. Manages the full
  lifecycle of accounts (personal and team), account membership, role-based
  authorization, and PubSub notifications for real-time UI updates.

  All public functions accept a `%Scope{}` as the first parameter for
  multi-tenant isolation.
  """

  use Boundary, deps: [MetricFlow], exports: [Account, AccountMember]

  alias MetricFlow.Accounts.Account
  alias MetricFlow.Accounts.AccountRepository
  alias MetricFlow.Users.Scope

  # ---------------------------------------------------------------------------
  # Delegated repository functions
  # ---------------------------------------------------------------------------

  defdelegate list_accounts(scope), to: AccountRepository
  defdelegate get_account!(scope, account_id), to: AccountRepository
  defdelegate create_team_account(scope, attrs), to: AccountRepository
  defdelegate update_account(scope, account, attrs), to: AccountRepository
  defdelegate delete_account(scope, account), to: AccountRepository
  defdelegate list_account_members(scope, account_id), to: AccountRepository
  defdelegate get_user_role(scope, user_id, account_id), to: AccountRepository
  defdelegate update_user_role(scope, user_id, account_id, role), to: AccountRepository
  defdelegate remove_user_from_account(scope, user_id, account_id), to: AccountRepository
  defdelegate add_user_to_account(scope, user_id, account_id, role), to: AccountRepository
  defdelegate leave_account(scope, account_id), to: AccountRepository
  defdelegate touch_membership(scope, account_id), to: AccountRepository
  defdelegate get_account_by_slug(slug), to: AccountRepository

  @doc """
  Returns the primary account ID for the scoped user.

  Used by AI and Correlations contexts to associate records with the user's account.
  Returns the ID of the user's first account, or nil if no accounts exist.
  """
  @spec get_personal_account_id(Scope.t()) :: integer() | nil
  defdelegate get_personal_account_id(scope), to: AccountRepository

  # ---------------------------------------------------------------------------
  # Changeset helpers
  # ---------------------------------------------------------------------------

  @doc """
  Returns an `%Ecto.Changeset{}` for the given account with no attrs applied.
  Suitable for initializing a live-validation form. Does not persist any changes.
  """
  @spec change_account(Scope.t(), Account.t()) :: Ecto.Changeset.t()
  def change_account(%Scope{}, %Account{} = account) do
    Account.changeset(account, %{})
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for the given account with the provided attrs
  applied. Suitable for driving live-validation. Does not persist any changes.
  """
  @spec change_account(Scope.t(), Account.t(), map()) :: Ecto.Changeset.t()
  def change_account(%Scope{}, %Account{} = account, attrs) do
    Account.changeset(account, attrs)
  end

  # ---------------------------------------------------------------------------
  # PubSub subscriptions
  # ---------------------------------------------------------------------------

  @doc """
  Subscribes the calling process to PubSub broadcasts for account-level events
  (created, updated, deleted) scoped to the current user.
  """
  @spec subscribe_account(Scope.t()) :: :ok | {:error, term()}
  def subscribe_account(%Scope{user: user}) do
    Phoenix.PubSub.subscribe(MetricFlow.PubSub, "accounts:user:#{user.id}")
  end

  @doc """
  Subscribes the calling process to PubSub broadcasts for member-level events
  (created, updated, deleted) scoped to the current user.
  """
  @spec subscribe_member(Scope.t()) :: :ok | {:error, term()}
  def subscribe_member(%Scope{user: user}) do
    Phoenix.PubSub.subscribe(MetricFlow.PubSub, "account_members:user:#{user.id}")
  end
end
