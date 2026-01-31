defmodule MetricFlow.Invitations.InvitationRepository do
  @moduledoc """
  Provides data access layer for invitation entities, handling invitation creation, token management,
  status tracking, and scoped queries within the multi-tenant architecture.
  """

  import Ecto.Query, warn: false
  alias MetricFlow.Repo
  alias MetricFlow.Invitations.Invitation

  # Basic CRUD Operations

  def create_invitation(_scope, %{account_id: account_id} = attrs)
      when not is_nil(account_id) do
    %Invitation{}
    |> Invitation.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, invitation} -> {:ok, Repo.preload(invitation, :account)}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc """
  Lists all invitations sent to a specific email address.

  ## Examples

      iex> list_user_invitations("user@example.com")
      [%Invitation{}, ...]

  """
  def list_user_invitations(email) when is_binary(email) do
    from(i in Invitation)
    |> by_email(email)
    |> pending()
    |> not_expired()
    |> Repo.all()
  end

  def get_invitation(_scope, id) do
    from(i in Invitation, preload: [:account])
    |> Repo.get(id)
  end

  def get_invitation!(_scope, id) do
    from(i in Invitation, preload: [:account])
    |> Repo.get!(id)
  end

  def update_invitation(_scope, invitation, attrs) do
    invitation
    |> Invitation.changeset(attrs)
    |> Repo.update()
  end

  def delete_invitation(_scope, invitation) do
    Repo.delete(invitation)
  end

  # Token Operations

  def get_invitation_by_token(token) do
    from(i in Invitation, where: i.token == ^token, preload: [:account, :invited_by])
    |> Repo.one()
  end

  def token_exists?(token) do
    Invitation
    |> where([i], i.token == ^token)
    |> Repo.exists?()
  end

  # Status Management

  def accept(_scope, invitation) do
    update_invitation_status(invitation, :accepted_at)
  end

  def cancel(
        _scope,
        %Invitation{} = invitation
      ) do
    update_invitation_status(invitation, :cancelled_at)
  end

  defp update_invitation_status(invitation, status_field) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    attrs = %{status_field => now}

    invitation
    |> Invitation.changeset(attrs)
    |> Repo.update()
  end

  # Query Builders

  def by_email(query, email) do
    where(query, [i], i.email == ^email)
  end

  def by_account(query, account_id) do
    where(query, [i], i.account_id == ^account_id)
  end

  def pending(query) do
    where(query, [i], is_nil(i.accepted_at) and is_nil(i.cancelled_at))
  end

  def not_expired(query) do
    now = DateTime.utc_now()
    where(query, [i], i.expires_at > ^now)
  end

  def accepted(query) do
    where(query, [i], not is_nil(i.accepted_at))
  end

  def cancelled(query) do
    where(query, [i], not is_nil(i.cancelled_at))
  end

  def expired(query) do
    now = DateTime.utc_now()
    where(query, [i], i.expires_at <= ^now and is_nil(i.accepted_at) and is_nil(i.cancelled_at))
  end

  # Bulk Operations

  def cleanup_expired_invitations(days_old) do
    cutoff_date = DateTime.utc_now() |> DateTime.add(-days_old, :day)

    from(i in Invitation)
    |> where([i], i.expires_at <= ^cutoff_date)
    |> expired()
    |> Repo.delete_all()
  end

  def list_pending_invitations(_scope, nil), do: []

  def list_pending_invitations(_scope, account_id) do
    from(i in Invitation)
    |> by_account(account_id)
    |> pending()
    |> not_expired()
    |> preload(:invited_by)
    |> Repo.all()
  end

  def count_pending_invitations(_scope, account_id)
      when not is_nil(account_id) do
    from(i in Invitation)
    |> by_account(account_id)
    |> pending()
    |> not_expired()
    |> Repo.aggregate(:count, :id)
  end

  def count_pending_invitations(_scope, nil), do: 0
end
