defmodule MetricFlow.Accounts do
  @moduledoc """
  Business accounts and membership management.

  Public API boundary for the Accounts bounded context. Manages the full
  lifecycle of accounts (personal and team), account membership, role-based
  authorization, and PubSub notifications for real-time UI updates.

  All public functions accept a `%Scope{}` as the first parameter for
  multi-tenant isolation.
  """

  use Boundary,
    deps: [MetricFlow, MetricFlow.Metrics, MetricFlow.Integrations, MetricFlow.Dashboards],
    exports: [Account, AccountMember, AccountOwnershipTransfer]

  import Ecto.Query, only: [from: 2]

  alias Ecto.Multi
  alias MetricFlow.Accounts.Account
  alias MetricFlow.Accounts.AccountMember
  alias MetricFlow.Accounts.AccountNotifier
  alias MetricFlow.Accounts.AccountOwnershipTransfer
  alias MetricFlow.Accounts.AccountOwnershipTransferNotifier
  alias MetricFlow.Accounts.AccountRepository
  alias MetricFlow.Accounts.Authorization
  alias MetricFlow.Repo
  alias MetricFlow.Users.Scope

  # ---------------------------------------------------------------------------
  # Delegated repository functions
  # ---------------------------------------------------------------------------

  defdelegate list_accounts(scope), to: AccountRepository
  defdelegate get_account!(scope, account_id), to: AccountRepository
  defdelegate create_team_account(scope, attrs), to: AccountRepository
  defdelegate create_team_account(scope, attrs, type), to: AccountRepository
  defdelegate update_account(scope, account, attrs), to: AccountRepository
  @doc """
  Deletes an account and emails the owner a deletion confirmation on success.
  """
  @spec delete_account(Scope.t(), Account.t()) :: {:ok, Account.t()} | {:error, :unauthorized}
  def delete_account(%Scope{} = scope, %Account{} = account) do
    with {:ok, deleted} <- AccountRepository.delete_account(scope, account) do
      _ = AccountNotifier.deliver_account_deletion_confirmation(scope.user.email, deleted.name)
      {:ok, deleted}
    end
  end
  defdelegate list_account_members(scope, account_id), to: AccountRepository
  defdelegate get_user_role(scope, user_id, account_id), to: AccountRepository
  defdelegate update_user_role(scope, user_id, account_id, role), to: AccountRepository
  defdelegate remove_user_from_account(scope, user_id, account_id), to: AccountRepository
  defdelegate add_user_to_account(scope, user_id, account_id, role), to: AccountRepository
  defdelegate leave_account(scope, account_id), to: AccountRepository
  defdelegate touch_membership(scope, account_id), to: AccountRepository
  defdelegate most_recently_switched_account_id(scope), to: AccountRepository
  defdelegate get_account_by_slug(slug), to: AccountRepository

  @doc """
  Returns true if the calling user may assign `target_role` to a member of the
  account — the same role-hierarchy check `add_user_to_account/4` and
  `update_user_role/4` enforce, exposed for callers outside this context (such
  as Invitations) that need to validate a target role before acting elsewhere.
  """
  @spec can_assign_role?(Scope.t(), integer(), atom()) :: boolean()
  def can_assign_role?(%Scope{} = scope, account_id, target_role) do
    Authorization.can?(scope, :add_member, %{account_id: account_id, target_role: target_role})
  end

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

  # ---------------------------------------------------------------------------
  # Ownership transfer
  # ---------------------------------------------------------------------------

  @doc """
  Initiates an ownership transfer for `account_id` on behalf of the scoped
  owner, to either an existing member (`transfer_target: "existing"` +
  `user_id`) or a new email (`transfer_target: "invite"` + `invite_email`).

  Only the account's current owner may call this. Supersedes any previously
  pending transfer for the same account. Emails the target a confirmation
  link; nothing about the account changes until that link is confirmed via
  `accept_ownership_transfer/2`.

  Returns `{:ok, transfer}` on success, `{:error, :unauthorized}` when the
  caller is not the account's owner, `{:error, :invalid_target}` when neither
  a valid existing member nor a usable invite email was given, or
  `{:error, changeset}` on validation failure.
  """
  @spec initiate_ownership_transfer(Scope.t(), integer(), map()) ::
          {:ok, AccountOwnershipTransfer.t()}
          | {:error, :unauthorized | :invalid_target | Ecto.Changeset.t()}
  def initiate_ownership_transfer(%Scope{} = scope, account_id, attrs) do
    with :ok <- authorize_owner(scope, account_id),
         {:ok, target} <- resolve_transfer_target(scope, account_id, attrs) do
      cancel_pending_transfers(account_id)
      do_initiate_transfer(scope, account_id, target, attrs)
    end
  end

  @doc """
  Returns the pending ownership transfer for `account_id`, if any.
  """
  @spec get_pending_ownership_transfer(Scope.t(), integer()) ::
          {:ok, AccountOwnershipTransfer.t()} | {:error, :not_found}
  def get_pending_ownership_transfer(%Scope{}, account_id) do
    query =
      from t in AccountOwnershipTransfer,
        where: t.account_id == ^account_id and t.status == :pending,
        order_by: [desc: t.inserted_at],
        limit: 1

    case Repo.one(query) do
      nil -> {:error, :not_found}
      transfer -> {:ok, transfer}
    end
  end

  @doc """
  Returns the most recently confirmed ownership transfer for `account_id`, if
  any — used to render the "both parties confirmed" log entry.
  """
  @spec get_latest_completed_ownership_transfer(Scope.t(), integer()) ::
          {:ok, AccountOwnershipTransfer.t()} | {:error, :not_found}
  def get_latest_completed_ownership_transfer(%Scope{}, account_id) do
    query =
      from t in AccountOwnershipTransfer,
        where: t.account_id == ^account_id and t.status == :confirmed,
        order_by: [desc: t.confirmed_at],
        limit: 1

    case Repo.one(query) do
      nil -> {:error, :not_found}
      transfer -> {:ok, transfer}
    end
  end

  @doc """
  Looks up a pending ownership transfer by its URL-safe token string.
  """
  @spec get_ownership_transfer_by_token(String.t()) ::
          {:ok, AccountOwnershipTransfer.t()} | {:error, :not_found}
  def get_ownership_transfer_by_token(encoded_token) when is_binary(encoded_token) do
    token_hash = AccountOwnershipTransfer.token_hash(encoded_token)

    case Repo.get_by(AccountOwnershipTransfer, token_hash: token_hash, status: :pending) do
      nil -> {:error, :not_found}
      transfer -> {:ok, Repo.preload(transfer, :account)}
    end
  end

  @doc """
  Confirms a pending ownership transfer on behalf of the authenticated user
  holding the token, re-assigning the :owner role to them and demoting the
  previous owner (to :admin if they chose to remain as admin, :account_manager
  otherwise). Emails both parties once complete.

  Returns `{:error, :not_authorized}` when the authenticated user is neither
  the invited existing member nor the invited email address.
  """
  @spec accept_ownership_transfer(Scope.t(), String.t()) ::
          {:ok, AccountOwnershipTransfer.t()} | {:error, :not_found | :not_authorized}
  def accept_ownership_transfer(%Scope{user: user} = scope, encoded_token)
      when is_binary(encoded_token) do
    with {:ok, transfer} <- get_ownership_transfer_by_token(encoded_token),
         :ok <- verify_transfer_recipient(transfer, user) do
      do_accept_transfer(scope, transfer)
    end
  end

  # ---------------------------------------------------------------------------
  # Private: ownership transfer
  # ---------------------------------------------------------------------------

  defp authorize_owner(scope, account_id) do
    if AccountRepository.get_user_role(scope, scope.user.id, account_id) == :owner do
      :ok
    else
      {:error, :unauthorized}
    end
  end

  defp resolve_transfer_target(_scope, _account_id, %{"transfer_target" => "invite"} = attrs) do
    resolve_invite_target(attrs["invite_email"])
  end

  defp resolve_transfer_target(_scope, _account_id, %{transfer_target: "invite"} = attrs) do
    resolve_invite_target(attrs[:invite_email])
  end

  defp resolve_transfer_target(scope, account_id, attrs) do
    user_id = parse_id_or_nil(attrs["user_id"] || attrs[:user_id])
    members = AccountRepository.list_account_members(scope, account_id)

    case Enum.find(members, &(&1.user_id == user_id)) do
      nil -> {:error, :invalid_target}
      member -> {:ok, %{user_id: member.user_id, email: member.user.email}}
    end
  end

  defp resolve_invite_target(email) when is_binary(email) and email != "" do
    {:ok, %{user_id: nil, email: email}}
  end

  defp resolve_invite_target(_email), do: {:error, :invalid_target}

  defp cancel_pending_transfers(account_id) do
    from(t in AccountOwnershipTransfer, where: t.account_id == ^account_id and t.status == :pending)
    |> Repo.delete_all()
  end

  defp do_initiate_transfer(scope, account_id, %{user_id: target_user_id, email: target_email}, attrs) do
    account = Repo.get!(Account, account_id)
    {encoded_token, token_changeset} = AccountOwnershipTransfer.build_token(%AccountOwnershipTransfer{})

    insert_attrs = %{
      account_id: account_id,
      initiated_by_user_id: scope.user.id,
      initiated_by_email: scope.user.email,
      target_user_id: target_user_id,
      target_email: target_email,
      remain_admin: truthy?(attrs["remain_admin"] || attrs[:remain_admin]),
      make_copy: truthy?(attrs["make_copy"] || attrs[:make_copy]),
      transfer_originator: truthy?(attrs["transfer_originator"] || attrs[:transfer_originator])
    }

    case token_changeset |> AccountOwnershipTransfer.changeset(insert_attrs) |> Repo.insert() do
      {:ok, transfer} ->
        confirm_url = build_transfer_url(encoded_token)

        _ =
          AccountOwnershipTransferNotifier.deliver_transfer_request(
            target_email,
            account.name,
            scope.user.email,
            confirm_url
          )

        {:ok, %{transfer | token: encoded_token}}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  defp verify_transfer_recipient(%AccountOwnershipTransfer{target_user_id: nil, target_email: email}, user) do
    if String.downcase(user.email) == String.downcase(email) do
      :ok
    else
      {:error, :not_authorized}
    end
  end

  defp verify_transfer_recipient(%AccountOwnershipTransfer{target_user_id: target_user_id}, user) do
    if target_user_id == user.id, do: :ok, else: {:error, :not_authorized}
  end

  defp do_accept_transfer(scope, %AccountOwnershipTransfer{} = transfer) do
    previous_owner_role = if transfer.remain_admin, do: :admin, else: :account_manager

    multi =
      Multi.new()
      |> Multi.run(:new_owner_member, fn repo, _changes ->
        upsert_member_role(repo, transfer.account_id, scope.user.id, :owner)
      end)
      |> Multi.run(:previous_owner_member, fn repo, _changes ->
        demote_previous_owner(repo, transfer, previous_owner_role)
      end)
      |> Multi.update(:transfer, AccountOwnershipTransfer.confirm_changeset(transfer))

    case Repo.transaction(multi) do
      {:ok, %{transfer: confirmed}} ->
        notify_transfer_completed(confirmed)
        {:ok, confirmed}

      {:error, _step, reason, _changes} ->
        {:error, reason}
    end
  end

  defp upsert_member_role(repo, account_id, user_id, role) do
    case repo.get_by(AccountMember, account_id: account_id, user_id: user_id) do
      nil ->
        %AccountMember{}
        |> AccountMember.changeset(%{account_id: account_id, user_id: user_id, role: role})
        |> repo.insert()

      member ->
        member |> AccountMember.role_changeset(%{role: role}) |> repo.update()
    end
  end

  defp demote_previous_owner(repo, %AccountOwnershipTransfer{} = transfer, role) do
    case repo.get_by(AccountMember,
           account_id: transfer.account_id,
           user_id: transfer.initiated_by_user_id
         ) do
      nil -> {:ok, nil}
      member -> member |> AccountMember.role_changeset(%{role: role}) |> repo.update()
    end
  end

  defp notify_transfer_completed(%AccountOwnershipTransfer{} = transfer) do
    account = Repo.get!(Account, transfer.account_id)
    primary_recipients = [transfer.initiated_by_email, transfer.target_email]

    # The previous and new owner are emailed first, in that order, matching
    # established behavior (and the spex asserting on it); any other account
    # member is notified afterward to satisfy criterion 74/905's "all users".
    other_recipients =
      transfer.account_id
      |> list_member_emails()
      |> Enum.reject(&(&1 in primary_recipients))

    (primary_recipients ++ other_recipients)
    |> Enum.each(fn email ->
      _ =
        AccountOwnershipTransferNotifier.deliver_transfer_completed(
          email,
          account.name,
          transfer.initiated_by_email,
          transfer.target_email
        )
    end)

    :ok
  end

  defp list_member_emails(account_id) do
    from(m in AccountMember,
      join: u in assoc(m, :user),
      where: m.account_id == ^account_id,
      select: u.email
    )
    |> Repo.all()
  end

  defp build_transfer_url(encoded_token) do
    base_url =
      Application.get_env(:metric_flow, MetricFlowWeb.Endpoint, [])
      |> Keyword.get(:url, [])
      |> Keyword.get(:host, "localhost")

    port =
      Application.get_env(:metric_flow, MetricFlowWeb.Endpoint, [])
      |> Keyword.get(:http, [])
      |> Keyword.get(:port, 4000)

    "http://#{base_url}:#{port}/account_transfers/#{encoded_token}"
  end

  defp parse_id_or_nil(nil), do: nil
  defp parse_id_or_nil(id) when is_integer(id), do: id

  defp parse_id_or_nil(id) when is_binary(id) do
    case Integer.parse(id) do
      {int, ""} -> int
      _ -> nil
    end
  end

  defp truthy?(true), do: true
  defp truthy?("true"), do: true
  defp truthy?("on"), do: true
  defp truthy?(_), do: false
end
