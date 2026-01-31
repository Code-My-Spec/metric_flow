defmodule MetricFlow.Invitations do
  @moduledoc """
  The Invitations context.

  Manages the complete invitation workflow for adding users to accounts, including token generation,
  email delivery, expiration handling, and invitation acceptance.
  """

  alias MetricFlow.Accounts
  alias MetricFlow.Authorization
  alias MetricFlow.Users
  alias MetricFlow.Users.Scope
  alias MetricFlow.Users.User
  alias MetricFlow.Accounts.Member
  alias MetricFlow.Invitations.{Invitation, InvitationRepository, InvitationNotifier}

  @doc """
  Subscribes to scoped notifications about invitation changes.

  The broadcasted messages match the pattern:

    * {:created, %Invitation{}}
    * {:updated, %Invitation{}}
    * {:deleted, %Invitation{}}

  """
  def subscribe_invitations(%Scope{} = scope) do
    key = scope.user.id
    Phoenix.PubSub.subscribe(MetricFlow.PubSub, "user:#{key}:invitations")
  end

  defp broadcast_invitation(%Scope{} = scope, message) do
    key = scope.user.id
    Phoenix.PubSub.broadcast(MetricFlow.PubSub, "user:#{key}:invitations", message)
  end

  @doc """
  Invites a user to join an account with the specified role.

  ## Examples

      iex> invite_user(scope, "user@example.com", :member)
      {:ok, %Invitation{}}

      iex> invite_user(scope, "invalid-email", :member)
      {:error, %Ecto.Changeset{}}

  """
  def invite_user(scope, account_id, email, role)
      when is_binary(email) and role in [:owner, :admin, :member] and not is_nil(account_id) do
    with :ok <- validate_manage_members_permission(scope, account_id),
         :ok <- validate_user_not_already_member(email, account_id),
         :ok <- validate_user_limit(account_id),
         {:ok, invitation} <- create_invitation(scope, account_id, email, role),
         :ok <- send_invitation_email(invitation) do
      broadcast_invitation(scope, {:created, invitation})
      {:ok, invitation}
    end
  end

  def invite_user(%Scope{active_account_id: nil}, _account_id, _email, _role) do
    {:error, :no_active_account}
  end

  @doc """
  Accepts an invitation using the provided token and user attributes.

  For new users, this creates a user account and adds them to the account.
  For existing users, this validates the email matches and adds them to the account.

  ## Examples

      iex> accept_invitation("valid_token", %{name: "John", email: "john@example.com"})
      {:ok, {%User{}, %Member{}}}

      iex> accept_invitation("invalid_token", %{})
      {:error, :invalid_token}

  """
  @spec accept_invitation(token :: String.t(), user_attrs :: map()) ::
          {:ok, {User.t(), Member.t()}}
          | {:error, :invalid_token | :expired_token | :email_mismatch | Ecto.Changeset.t()}
  def accept_invitation(token, user_attrs) when is_binary(token) and is_map(user_attrs) do
    with {:ok, invitation} <- get_valid_invitation(token),
         {:ok, user} <- resolve_or_create_user(invitation, user_attrs),
         {:ok, member} <- add_user_to_account(user, invitation),
         {:ok, _updated_invitation} <- mark_invitation_accepted(invitation) do
      send_welcome_email(user, invitation)
      {:ok, {user, member}}
    end
  end

  @doc """
  Lists all pending invitations for the current account.

  ## Examples

      iex> list_pending_invitations(scope)
      [%Invitation{}, ...]

  """
  @spec list_pending_invitations(scope :: Scope.t(), account_id :: integer()) :: [Invitation.t()]
  def list_pending_invitations(scope, account_id)
      when not is_nil(account_id) do
    with :ok <- validate_read_account_permission(scope, account_id) do
      InvitationRepository.list_pending_invitations(scope, account_id)
    else
      _ -> []
    end
  end

  def list_pending_invitations(_scope, nil), do: []

  @doc """
  Lists all invitations sent to a specific email address.

  ## Examples

      iex> list_user_invitations("user@example.com")
      [%Invitation{}, ...]

  """
  defdelegate list_user_invitations(email), to: InvitationRepository

  @doc """
  Cancels an invitation.

  ## Examples

      iex> cancel_invitation(scope, 123)
      {:ok, %Invitation{}}

      iex> cancel_invitation(scope, 999)
      {:error, :not_found}

  """
  @spec cancel_invitation(scope :: Scope.t(), account_id :: integer(), invitation_id :: integer()) ::
          {:ok, Invitation.t()} | {:error, :not_found | :not_authorized | :no_active_account}
  def cancel_invitation(scope, account_id, invitation_id)
      when is_integer(invitation_id) and not is_nil(account_id) do
    with :ok <- validate_manage_members_permission(scope, account_id),
         {:ok, invitation} <- get_invitation_for_account(invitation_id, account_id),
         {:ok, cancelled_invitation} <- InvitationRepository.cancel(scope, invitation) do
      send_cancellation_email(cancelled_invitation)
      broadcast_invitation(scope, {:updated, cancelled_invitation})
      {:ok, cancelled_invitation}
    end
  end

  @spec cancel_invitation(MetricFlow.Users.Scope.t(), any()) :: {:error, :no_active_account}
  def cancel_invitation(%Scope{active_account_id: nil}, _invitation_id) do
    {:error, :no_active_account}
  end

  @doc """
  Gets an invitation by its token.

  ## Examples

      iex> get_invitation_by_token("valid_token")
      %Invitation{}

      iex> get_invitation_by_token("invalid_token")
      nil

  """
  @spec get_invitation_by_token(token :: String.t()) :: Invitation.t() | nil
  def get_invitation_by_token(token) when is_binary(token) do
    InvitationRepository.get_invitation_by_token(token)
  end

  @doc """
  Cleans up expired invitations.

  ## Examples

      iex> cleanup_expired_invitations()
      :ok

  """
  @spec cleanup_expired_invitations() :: :ok
  def cleanup_expired_invitations do
    InvitationRepository.cleanup_expired_invitations(30)
    :ok
  end

  # Private helper functions

  defp validate_manage_members_permission(scope, account_id) do
    if Authorization.authorize(:manage_members, scope, account_id) do
      :ok
    else
      {:error, :not_authorized}
    end
  end

  defp validate_read_account_permission(scope, account_id) do
    if Authorization.authorize(:read_account, scope, account_id) do
      :ok
    else
      {:error, :not_authorized}
    end
  end

  defp validate_user_not_already_member(email, account_id) do
    case Users.get_user_by_email(email) do
      nil ->
        :ok

      user ->
        if Accounts.user_has_account_access?(%Scope{user: user}, account_id) do
          {:error, :user_already_member}
        else
          :ok
        end
    end
  end

  defp validate_user_limit(account_id) do
    # TODO: Add user limit validation when billing context is implemented
    case MetricFlow.Accounts.MembersRepository.can_add_user_to_account?(account_id) do
      true -> :ok
    end
  end

  defp create_invitation(scope, account_id, email, role) do
    attrs = %{
      email: email,
      role: role,
      account_id: account_id,
      invited_by_id: scope.user.id
    }

    InvitationRepository.create_invitation(scope, attrs)
  end

  defp send_invitation_email(invitation) do
    # In a real implementation, you would generate the proper URL
    url = "#{MetricFlowWeb.Endpoint.url()}/invitations/accept/#{invitation.token}"

    case InvitationNotifier.deliver_invitation_email(invitation, url) do
      {:ok, _} -> :ok
      {:error, _} -> {:error, :email_delivery_failed}
    end
  end

  defp get_valid_invitation(token) do
    case InvitationRepository.get_invitation_by_token(token) do
      nil ->
        {:error, :invalid_token}

      invitation ->
        if DateTime.after?(invitation.expires_at, DateTime.utc_now()) do
          if is_nil(invitation.accepted_at) and is_nil(invitation.cancelled_at) do
            {:ok, invitation}
          else
            {:error, :invalid_token}
          end
        else
          {:error, :expired_token}
        end
    end
  end

  defp resolve_or_create_user(invitation, %{email: provided_email} = user_attrs) do
    if provided_email == invitation.email do
      case Users.get_user_by_email(invitation.email) do
        nil -> Users.register_user(user_attrs)
        existing_user -> {:ok, existing_user}
      end
    else
      {:error, :email_mismatch}
    end
  end

  defp resolve_or_create_user(invitation, user_attrs) do
    # No email provided, use invitation email
    user_attrs_with_email = Map.put(user_attrs, :email, invitation.email)

    case Users.get_user_by_email(invitation.email) do
      nil -> Users.register_user(user_attrs_with_email)
      existing_user -> {:ok, existing_user}
    end
  end

  defp add_user_to_account(user, invitation) do
    # Get the inviter to create a scope with proper permissions
    inviter = Users.get_user!(invitation.invited_by_id)
    inviter_scope = %Scope{user: inviter, active_account_id: invitation.account_id}

    Accounts.add_user_to_account(inviter_scope, user.id, invitation.account_id, invitation.role)
  end

  defp mark_invitation_accepted(invitation) do
    scope = %Scope{active_account_id: invitation.account_id}
    InvitationRepository.accept(scope, invitation)
  end

  defp send_welcome_email(user, invitation) do
    case InvitationNotifier.deliver_welcome_email(user, invitation.account) do
      {:ok, _} -> :ok
      {:error, _} -> :ok
    end
  end

  defp send_cancellation_email(invitation) do
    case InvitationNotifier.deliver_invitation_cancelled(invitation) do
      {:ok, _} -> :ok
      # Don't fail the whole process if cancellation email fails
      {:error, _} -> :ok
    end
  end

  defp get_invitation_for_account(invitation_id, account_id) do
    scope = %Scope{active_account_id: account_id}

    case InvitationRepository.get_invitation(scope, invitation_id) do
      nil -> {:error, :not_found}
      invitation -> {:ok, invitation}
    end
  end
end
