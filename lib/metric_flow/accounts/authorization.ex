defmodule MetricFlow.Accounts.Authorization do
  @moduledoc """
  Role-based authorization module providing can?/3 predicate functions for all
  account operations.

  Accepts a Scope struct, an action atom, and a context map containing the
  account_id and optionally a target_role. Encodes the role hierarchy:
  owner > admin > account_manager > read_only. Looks up the calling user's role
  from the database, then evaluates permissions based on that role and the
  requested action. Returns false for any user who is not a member of the account.

  Role hierarchy rules for assigning roles:
  - Owners may assign any role (:owner, :admin, :account_manager, :read_only)
  - Admins may only assign roles strictly below their own (:account_manager, :read_only)
  """

  import Ecto.Query, only: [from: 2]

  alias MetricFlow.Accounts.AccountMember
  alias MetricFlow.Repo
  alias MetricFlow.Users.Scope

  @type action ::
          :update_account
          | :delete_account
          | :add_member
          | :remove_member
          | :update_user_role
          | :leave_account

  @doc """
  Returns true if the calling user has permission to perform the given action
  in the given account, false otherwise.

  Looks up the caller's current role from the database via AccountMember, then
  applies the role-hierarchy permission rules for the requested action. For
  actions that involve assigning a role to another user (:add_member,
  :update_user_role), also validates that the caller is not attempting to assign
  a role at or above their own level.
  """
  @spec can?(Scope.t(), atom(), map()) :: boolean()
  def can?(%Scope{user: nil}, _action, _context), do: false

  def can?(%Scope{user: user}, action, context) do
    account_id = Map.fetch!(context, :account_id)

    case fetch_role(user.id, account_id) do
      nil -> false
      role -> permitted?(role, action, context)
    end
  end

  # ---------------------------------------------------------------------------
  # Permission rules
  # ---------------------------------------------------------------------------

  defp permitted?(:owner, :update_account, _context), do: true
  defp permitted?(:admin, :update_account, _context), do: true
  defp permitted?(_role, :update_account, _context), do: false

  defp permitted?(:owner, :delete_account, _context), do: true
  defp permitted?(_role, :delete_account, _context), do: false

  defp permitted?(:owner, :add_member, _context), do: true
  defp permitted?(:admin, :add_member, context), do: target_role_allowed?(:admin, context)
  defp permitted?(_role, :add_member, _context), do: false

  defp permitted?(:owner, :remove_member, _context), do: true
  defp permitted?(:admin, :remove_member, _context), do: true
  defp permitted?(_role, :remove_member, _context), do: false

  defp permitted?(:owner, :update_user_role, _context), do: true
  defp permitted?(:admin, :update_user_role, context), do: target_role_allowed?(:admin, context)
  defp permitted?(_role, :update_user_role, _context), do: false

  defp permitted?(:owner, :leave_account, _context), do: false
  defp permitted?(_role, :leave_account, _context), do: true

  defp permitted?(_role, _unknown_action, _context), do: false

  # ---------------------------------------------------------------------------
  # Role hierarchy helpers
  # ---------------------------------------------------------------------------

  # Admins may only assign roles strictly below their own level: :account_manager or :read_only.
  # They cannot assign :owner or :admin.
  defp target_role_allowed?(:admin, %{target_role: :owner}), do: false
  defp target_role_allowed?(:admin, %{target_role: :admin}), do: false
  defp target_role_allowed?(:admin, %{target_role: _role}), do: true
  defp target_role_allowed?(:admin, _context), do: true

  # ---------------------------------------------------------------------------
  # Database lookup
  # ---------------------------------------------------------------------------

  defp fetch_role(user_id, account_id) do
    query =
      from m in AccountMember,
        where: m.user_id == ^user_id and m.account_id == ^account_id,
        select: m.role

    Repo.one(query)
  end
end
