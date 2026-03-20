defmodule MetricFlow.Accounts.AccountRepository do
  @moduledoc """
  Data access layer for Account and AccountMember CRUD operations.

  All query functions filter by the calling user's identity extracted from the
  Scope struct for multi-tenant isolation. Handles transactional operations —
  account creation atomically inserts the account and owner membership record,
  and account deletion atomically removes all member records before removing the
  account. Broadcasts PubSub events after successful mutations.
  """

  import Ecto.Query

  alias Ecto.Multi
  alias MetricFlow.Accounts.Account
  alias MetricFlow.Accounts.AccountMember
  alias MetricFlow.Accounts.Authorization
  alias MetricFlow.Repo
  alias MetricFlow.Users.Scope

  @pubsub MetricFlow.PubSub

  # ---------------------------------------------------------------------------
  # Account queries
  # ---------------------------------------------------------------------------

  @doc """
  Returns all accounts the user belongs to, ordered by membership insertion
  date (most recently joined first). Includes both personal and team accounts.
  """
  @spec list_accounts(Scope.t()) :: list(Account.t())
  def list_accounts(%Scope{user: user}) do
    from(a in Account,
      join: m in AccountMember,
      on: m.account_id == a.id and m.user_id == ^user.id,
      order_by: [desc: m.updated_at, desc: m.id]
    )
    |> Repo.all()
  end

  @doc """
  Fetches a single account by ID, scoped to ensure the calling user is a member.
  Raises Ecto.NoResultsError when the account does not exist or the user is not
  a member.
  """
  @spec get_account!(Scope.t(), integer()) :: Account.t()
  def get_account!(%Scope{user: user}, account_id) do
    from(a in Account,
      join: m in AccountMember,
      on: m.account_id == a.id and m.user_id == ^user.id,
      where: a.id == ^account_id
    )
    |> Repo.one!()
  end

  # ---------------------------------------------------------------------------
  # Account mutations
  # ---------------------------------------------------------------------------

  @doc """
  Creates a new team account and adds the calling user as the owner.
  Validates required fields and slug uniqueness. Executes atomically within
  a transaction. Broadcasts {:created, account} on success.
  """
  @spec create_team_account(Scope.t(), map()) ::
          {:ok, Account.t()} | {:error, Ecto.Changeset.t()}
  def create_team_account(%Scope{user: user}, attrs) do
    # Normalize attrs to string keys to avoid mixed-key maps when merging
    # server-controlled fields (type, originator_user_id) with user-provided
    # form params that arrive as string-keyed maps from LiveView.
    string_attrs = for {k, v} <- attrs, into: %{}, do: {to_string(k), v}

    account_attrs =
      Map.merge(string_attrs, %{
        "type" => "team",
        "originator_user_id" => user.id
      })

    account_changeset = Account.creation_changeset(%Account{}, account_attrs)

    multi =
      Multi.new()
      |> Multi.insert(:account, account_changeset)
      |> Multi.insert(:member, fn %{account: account} ->
        AccountMember.changeset(%AccountMember{}, %{
          account_id: account.id,
          user_id: user.id,
          role: :owner
        })
      end)

    case Repo.transaction(multi) do
      {:ok, %{account: account}} ->
        broadcast("accounts:user:#{user.id}", {:created, account})
        {:ok, account}

      {:error, :account, changeset, _changes} ->
        {:error, changeset}

      {:error, :member, changeset, _changes} ->
        {:error, changeset}
    end
  end

  @doc """
  Updates an existing account's attributes. Only owners and admins may update
  an account. Validates the name and slug fields. Broadcasts {:updated, account}
  on success.
  """
  @spec update_account(Scope.t(), Account.t(), map()) ::
          {:ok, Account.t()} | {:error, Ecto.Changeset.t()} | {:error, :unauthorized}
  def update_account(%Scope{user: user} = scope, %Account{} = account, attrs) do
    with true <- Authorization.can?(scope, :update_account, %{account_id: account.id}),
         {:ok, updated} <- account |> Account.changeset(attrs) |> Repo.update() do
      broadcast("accounts:user:#{user.id}", {:updated, updated})
      {:ok, updated}
    else
      false -> {:error, :unauthorized}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc """
  Deletes an account and all associated membership records atomically.
  Only owners may delete an account. Personal accounts cannot be deleted.
  Broadcasts {:deleted, account} on success.
  """
  @spec delete_account(Scope.t(), Account.t()) ::
          {:ok, Account.t()} | {:error, :unauthorized} | {:error, :personal_account}
  def delete_account(_scope, %Account{type: "personal"}), do: {:error, :personal_account}

  def delete_account(%Scope{user: user} = scope, %Account{} = account) do
    with true <- Authorization.can?(scope, :delete_account, %{account_id: account.id}),
         {:ok, %{account: deleted}} <- run_delete_account_transaction(account) do
      broadcast("accounts:user:#{user.id}", {:deleted, deleted})
      {:ok, deleted}
    else
      false -> {:error, :unauthorized}
    end
  end

  defp run_delete_account_transaction(%Account{} = account) do
    Multi.new()
    |> Multi.delete_all(:members, from(m in AccountMember, where: m.account_id == ^account.id))
    |> Multi.delete(:account, account)
    |> Repo.transaction()
  end

  # ---------------------------------------------------------------------------
  # Member queries
  # ---------------------------------------------------------------------------

  @doc """
  Returns all members of the given account with their associated user records
  preloaded. Scoped to ensure the calling user is a member of the account.
  Raises Ecto.NoResultsError if the calling user is not a member.
  """
  @spec list_account_members(Scope.t(), integer()) :: list(AccountMember.t())
  def list_account_members(%Scope{user: user}, account_id) do
    from(m in AccountMember,
      where: m.account_id == ^account_id and m.user_id == ^user.id
    )
    |> Repo.one!()

    from(m in AccountMember,
      where: m.account_id == ^account_id,
      preload: [:user],
      order_by: [asc: m.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Returns the role of a specific user in a given account.
  Returns nil if the user is not a member.
  """
  @spec get_user_role(Scope.t(), integer(), integer()) :: atom() | nil
  def get_user_role(%Scope{}, user_id, account_id) do
    from(m in AccountMember,
      where: m.user_id == ^user_id and m.account_id == ^account_id,
      select: m.role
    )
    |> Repo.one()
  end

  # ---------------------------------------------------------------------------
  # Member mutations
  # ---------------------------------------------------------------------------

  @doc """
  Changes the role of a user within an account. Enforces role hierarchy: only
  owners can promote to owner or admin, admins can only assign account_manager
  or read_only. The last owner of an account cannot be demoted.
  Broadcasts {:updated, member} on success.
  """
  @spec update_user_role(Scope.t(), integer(), integer(), atom()) ::
          {:ok, AccountMember.t()}
          | {:error, :unauthorized}
          | {:error, :last_owner}
          | {:error, Ecto.Changeset.t()}
  def update_user_role(%Scope{} = scope, target_user_id, account_id, role) do
    with true <-
           Authorization.can?(scope, :update_user_role, %{
             account_id: account_id,
             target_role: role
           }),
         %AccountMember{} = member <- fetch_member!(target_user_id, account_id),
         :ok <- check_last_owner(member, account_id),
         {:ok, updated} <-
           member |> AccountMember.role_changeset(%{role: role}) |> Repo.update() do
      broadcast("account_members:user:#{target_user_id}", {:updated, updated})
      {:ok, updated}
    else
      false -> {:error, :unauthorized}
      {:error, :last_owner} -> {:error, :last_owner}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc """
  Removes a user from an account. Owners and admins may remove members.
  The last owner of an account cannot be removed.
  Broadcasts {:deleted, member} on success.
  """
  @spec remove_user_from_account(Scope.t(), integer(), integer()) ::
          {:ok, AccountMember.t()} | {:error, :unauthorized} | {:error, :last_owner}
  def remove_user_from_account(%Scope{} = scope, target_user_id, account_id) do
    with true <-
           Authorization.can?(scope, :remove_member, %{account_id: account_id}),
         %AccountMember{} = member <- fetch_member!(target_user_id, account_id),
         :ok <- check_last_owner(member, account_id),
         {:ok, deleted} <- Repo.delete(member) do
      broadcast("account_members:user:#{target_user_id}", {:deleted, deleted})
      {:ok, deleted}
    else
      false -> {:error, :unauthorized}
      {:error, :last_owner} -> {:error, :last_owner}
    end
  end

  @doc """
  Allows a non-owner member to remove themselves from an account.
  Owners cannot leave an account — they must transfer ownership first.
  Broadcasts {:deleted, member} on success.
  """
  @spec leave_account(Scope.t(), integer()) ::
          {:ok, AccountMember.t()} | {:error, :unauthorized} | {:error, :not_found}
  def leave_account(%Scope{user: user} = scope, account_id) do
    with true <- Authorization.can?(scope, :leave_account, %{account_id: account_id}),
         %AccountMember{} = member <- fetch_member!(user.id, account_id),
         {:ok, deleted} <- Repo.delete(member) do
      broadcast("account_members:user:#{user.id}", {:deleted, deleted})
      {:ok, deleted}
    else
      false -> {:error, :unauthorized}
    end
  end

  @doc """
  Adds a user to an account with the given role. Only owners and admins may add
  members. Only owners can add members with the owner role.
  Broadcasts {:created, member} on success.
  """
  @spec add_user_to_account(Scope.t(), integer(), integer(), atom()) ::
          {:ok, AccountMember.t()}
          | {:error, :unauthorized}
          | {:error, :already_member}
          | {:error, Ecto.Changeset.t()}
  def add_user_to_account(%Scope{} = scope, target_user_id, account_id, role) do
    with true <-
           Authorization.can?(scope, :add_member, %{
             account_id: account_id,
             target_role: role
           }),
         false <- member_exists?(target_user_id, account_id),
         {:ok, member} <-
           AccountMember.changeset(%AccountMember{}, %{
             account_id: account_id,
             user_id: target_user_id,
             role: role
           })
           |> Repo.insert() do
      broadcast("account_members:user:#{target_user_id}", {:created, member})
      {:ok, member}
    else
      false -> {:error, :unauthorized}
      true -> {:error, :already_member}
      {:error, changeset} -> {:error, changeset}
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp fetch_member!(user_id, account_id) do
    Repo.get_by!(AccountMember, user_id: user_id, account_id: account_id)
  end

  defp member_exists?(user_id, account_id) do
    Repo.exists?(
      from m in AccountMember,
        where: m.user_id == ^user_id and m.account_id == ^account_id
    )
  end

  defp check_last_owner(%AccountMember{role: :owner}, account_id) do
    owner_count =
      from(m in AccountMember,
        where: m.account_id == ^account_id and m.role == :owner,
        select: count()
      )
      |> Repo.one()

    if owner_count <= 1, do: {:error, :last_owner}, else: :ok
  end

  defp check_last_owner(%AccountMember{}, _account_id), do: :ok

  @doc """
  Returns the ID of the user's first account, or nil if none exist.
  """
  @spec get_personal_account_id(Scope.t()) :: integer() | nil
  def get_personal_account_id(%Scope{user: user}) do
    from(m in AccountMember, where: m.user_id == ^user.id, select: m.account_id, limit: 1)
    |> Repo.one()
  end

  @doc """
  Touches the `updated_at` timestamp on the user's membership for the given
  account, so `list_accounts/1` (ordered by `updated_at DESC`) returns this
  account first on subsequent page loads.
  """
  @spec touch_membership(Scope.t(), integer()) :: :ok
  def touch_membership(%Scope{user: user}, account_id) do
    from(m in AccountMember,
      where: m.user_id == ^user.id and m.account_id == ^account_id
    )
    |> Repo.update_all(set: [updated_at: DateTime.utc_now()])

    :ok
  end

  @doc """
  Finds a team account by its slug.

  Returns the account struct or nil when no team account matches the slug.
  """
  @spec get_account_by_slug(String.t()) :: Account.t() | nil
  def get_account_by_slug(slug) do
    from(a in Account,
      where: a.slug == ^slug and a.type == "team"
    )
    |> Repo.one()
  end

  defp broadcast(topic, message) do
    Phoenix.PubSub.broadcast(@pubsub, topic, message)
  end
end
