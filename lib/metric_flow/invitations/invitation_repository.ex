defmodule MetricFlow.Invitations.InvitationRepository do
  @moduledoc """
  Data access layer for Invitation CRUD operations.

  Queries that take a Scope filter by `account_id` for multi-tenant isolation.
  Provides CRUD operations and a token-hash lookup used by the acceptance flow.
  """

  import Ecto.Query

  alias MetricFlow.Accounts.AccountMember
  alias MetricFlow.Invitations.Invitation
  alias MetricFlow.Repo
  alias MetricFlow.Users.Scope

  @doc """
  Inserts a new invitation record from the given changeset.

  Returns `{:ok, invitation}` on success or `{:error, changeset}` on validation
  or constraint failure.
  """
  @spec create_invitation(Ecto.Changeset.t()) :: {:ok, Invitation.t()} | {:error, Ecto.Changeset.t()}
  def create_invitation(%Ecto.Changeset{} = changeset) do
    Repo.insert(changeset)
  end

  @doc """
  Looks up an invitation by its stored token hash.

  Preloads the `:account` and `:invited_by` associations. Returns the invitation
  struct or nil when no match is found.
  """
  @spec get_by_token_hash(binary()) :: Invitation.t() | nil
  def get_by_token_hash(token_hash) when is_binary(token_hash) do
    from(i in Invitation,
      where: i.token_hash == ^token_hash,
      preload: [:account, :invited_by]
    )
    |> Repo.one()
  end

  @doc """
  Returns all pending invitations for the given account scoped to the caller's
  membership. Orders results by insertion date descending.
  """
  @spec list_invitations(Scope.t(), integer()) :: list(Invitation.t())
  def list_invitations(%Scope{}, account_id) do
    from(i in Invitation,
      where: i.account_id == ^account_id and i.status == :pending,
      order_by: [desc: i.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Fetches a single invitation by ID scoped to accounts the calling user belongs to.

  Returns `{:ok, invitation}` when found or `{:error, :not_found}` when the
  invitation does not exist or the caller does not have access.
  """
  @spec get_invitation(Scope.t(), integer()) :: {:ok, Invitation.t()} | {:error, :not_found}
  def get_invitation(%Scope{user: user}, invitation_id) do
    query =
      from(i in Invitation,
        join: m in AccountMember,
        on: m.account_id == i.account_id and m.user_id == ^user.id,
        where: i.id == ^invitation_id
      )

    case Repo.one(query) do
      nil -> {:error, :not_found}
      invitation -> {:ok, invitation}
    end
  end

  @doc """
  Updates an invitation using a changeset.

  Returns `{:ok, invitation}` on success or `{:error, changeset}` on failure.
  """
  @spec update_invitation(Invitation.t(), Ecto.Changeset.t()) ::
          {:ok, Invitation.t()} | {:error, Ecto.Changeset.t()}
  def update_invitation(%Invitation{}, %Ecto.Changeset{} = changeset) do
    Repo.update(changeset)
  end
end
