defmodule MetricFlow.Invitations do
  @moduledoc """
  Invitation flow for granting account access.

  Manages the full lifecycle of account access invitations: creating and sending
  invitations by email, validating tokens on the acceptance page, and granting
  account membership when an invitation is accepted.

  Invitations carry a hashed token — the raw token is sent to the invitee and
  never stored. Tokens expire after 7 days. Each invitation targets a specific
  email address, account, and role. Accepted or declined invitations cannot be
  reused.

  All public functions accept a `%Scope{}` as the first parameter for
  multi-tenant isolation.
  """

  use Boundary, deps: [MetricFlow], exports: [Invitation]

  import Ecto.Query, only: [from: 2]

  alias Ecto.Multi
  alias MetricFlow.Accounts.Account
  alias MetricFlow.Accounts.AccountMember
  alias MetricFlow.Invitations.Invitation
  alias MetricFlow.Invitations.InvitationNotifier
  alias MetricFlow.Invitations.InvitationRepository
  alias MetricFlow.Repo
  alias MetricFlow.Users.Scope

  @invitation_validity_in_days 7
  @pubsub MetricFlow.PubSub

  # ---------------------------------------------------------------------------
  # Delegated repository functions
  # ---------------------------------------------------------------------------

  defdelegate list_invitations(scope, account_id), to: InvitationRepository
  defdelegate get_invitation(scope, invitation_id), to: InvitationRepository

  # ---------------------------------------------------------------------------
  # send_invitation/3
  # ---------------------------------------------------------------------------

  @doc """
  Creates an invitation record and delivers an invitation email to the recipient.

  Only owners and admins may send invitations. The invitation is scoped to the
  given account_id. A cryptographically secure token is generated and stored as
  a hash. The invitation expires in 7 days.

  Accepts `recipient_email` or `email` as the email key in attrs.

  Returns `{:ok, invitation}` on success or an error tuple:
  - `{:error, :unauthorized}` when the caller lacks permission
  - `{:error, changeset}` when attrs are invalid
  """
  @spec send_invitation(Scope.t(), integer(), map()) ::
          {:ok, Invitation.t()} | {:error, :unauthorized | Ecto.Changeset.t()}
  def send_invitation(%Scope{user: user} = scope, account_id, attrs) do
    with :ok <- authorize_invite(scope, account_id) do
      account = Repo.get!(Account, account_id)

      expires_at = DateTime.add(DateTime.utc_now(:second), @invitation_validity_in_days, :day)

      invitation_attrs =
        attrs
        |> to_atom_keys()
        |> normalize_email_key()
        |> Map.put(:expires_at, expires_at)
        |> Map.put(:account_id, account_id)
        |> Map.put(:invited_by_user_id, user.id)

      {encoded_token, token_changeset} = Invitation.build_token(%Invitation{})
      full_changeset = apply_changeset(token_changeset, invitation_attrs)

      insert_and_notify(full_changeset, encoded_token, account.name)
    end
  end

  # ---------------------------------------------------------------------------
  # get_invitation_by_token/1
  # ---------------------------------------------------------------------------

  @doc """
  Looks up a pending invitation by its URL-safe token string.

  Returns the invitation with the associated account and inviting user preloaded
  when the token is valid and the invitation has not been used or expired.

  Returns an error atom describing why the invitation cannot be used:
  - `{:error, :not_found}` — no invitation matches this token or it has been
    accepted or declined
  - `{:error, :expired}` — invitation exists but is past its expiry date
  """
  @spec get_invitation_by_token(String.t()) ::
          {:ok, Invitation.t()} | {:error, :not_found | :expired}
  def get_invitation_by_token(encoded_token) when is_binary(encoded_token) do
    encoded_token
    |> Invitation.token_hash()
    |> lookup_invitation()
  end

  # ---------------------------------------------------------------------------
  # accept_invitation/2 (scope-based)
  # ---------------------------------------------------------------------------

  @doc """
  Accepts a pending invitation on behalf of the authenticated user.

  Adds the user to the account with the invitation's role and marks the
  invitation as accepted. Returns `{:error, :already_member}` when the user
  is already a member of the invitation's account.

  Returns `{:ok, member}` on success or an error tuple:
  - `{:error, :not_found}` — token does not match any pending invitation
  - `{:error, :expired}` — invitation has expired
  - `{:error, :already_member}` — user is already a member of the account
  """
  @spec accept_invitation(Scope.t(), String.t()) ::
          {:ok, AccountMember.t()}
          | {:error, :not_found | :expired | :already_member}
  def accept_invitation(%Scope{user: user}, encoded_token) when is_binary(encoded_token) do
    with {:ok, invitation} <- get_invitation_by_token(encoded_token) do
      do_accept(invitation, user)
    end
  end

  defp do_accept(invitation, user) do
    case check_not_already_member(user.id, invitation.account_id) do
      {:error, :already_member} ->
        # Invalidate the token even when the user is already a member so that
        # a second visit to the acceptance URL shows "invalid or already used".
        _ = Repo.update(Invitation.accept_changeset(invitation))
        {:error, :already_member}

      :ok ->
        insert_member_and_accept(invitation, user)
    end
  end

  defp insert_member_and_accept(invitation, user) do
    multi =
      Multi.new()
      |> Multi.insert(:member, fn _changes ->
        AccountMember.changeset(%AccountMember{}, %{
          user_id: user.id,
          account_id: invitation.account_id,
          role: invitation.role
        })
      end)
      |> Multi.update(:invitation, fn _changes ->
        Invitation.accept_changeset(invitation)
      end)

    case Repo.transaction(multi) do
      {:ok, %{member: member}} ->
        Phoenix.PubSub.broadcast(@pubsub, "accounts:user:#{user.id}", {:member_added, member})
        {:ok, member}

      {:error, _op, changeset, _changes} ->
        {:error, changeset}
    end
  end

  # ---------------------------------------------------------------------------
  # decline_invitation/2
  # ---------------------------------------------------------------------------

  @doc """
  Declines a pending invitation on behalf of the authenticated user.

  Marks the invitation as declined without adding the user to the account.

  Returns `{:ok, invitation}` with the updated invitation struct on success or
  an error tuple:
  - `{:error, :not_found}` — token does not match any pending invitation
  - `{:error, :expired}` — invitation has expired
  """
  @spec decline_invitation(Scope.t(), String.t()) ::
          {:ok, Invitation.t()} | {:error, :not_found | :expired}
  def decline_invitation(%Scope{}, encoded_token) when is_binary(encoded_token) do
    with {:ok, invitation} <- get_invitation_by_token(encoded_token) do
      decline_cs = Invitation.decline_changeset(invitation)
      InvitationRepository.update_invitation(invitation, decline_cs)
    end
  end

  # ---------------------------------------------------------------------------
  # cancel_invitation/2
  # ---------------------------------------------------------------------------

  @doc """
  Cancels a pending invitation by its ID on behalf of an authorized user.

  Marks the invitation as declined. Returns `{:error, :not_found}` when the
  invitation does not exist, has already been accepted, or the caller does not
  have access to the invitation's account. Returns `{:error, :not_pending}`
  when the invitation exists but is no longer in pending status.

  Returns `{:ok, invitation}` on success.
  """
  @spec cancel_invitation(Scope.t(), integer()) ::
          {:ok, Invitation.t()} | {:error, :not_found | :not_pending}
  def cancel_invitation(%Scope{} = scope, invitation_id) when is_integer(invitation_id) do
    with {:ok, invitation} <- get_invitation(scope, invitation_id),
         :ok <- check_pending(invitation) do
      decline_cs = Invitation.decline_changeset(invitation)
      InvitationRepository.update_invitation(invitation, decline_cs)
    end
  end

  # ---------------------------------------------------------------------------
  # change_invitation/2
  # ---------------------------------------------------------------------------

  @doc """
  Returns an `%Ecto.Changeset{}` for a new invitation with the provided attrs
  applied. Suitable for driving live-validation on the send invitation form.
  Does not persist any changes.
  """
  @spec change_invitation(Scope.t(), map()) :: Ecto.Changeset.t()
  def change_invitation(%Scope{}, attrs) do
    Invitation.changeset(%Invitation{}, attrs)
  end

  # ---------------------------------------------------------------------------
  # create_invitation/1 — test / seed helper
  # ---------------------------------------------------------------------------

  @doc """
  Creates an invitation from a plain attrs map and returns `{:ok, invitation}`
  where `invitation.token` is populated with the encoded URL-safe token.

  Intended for use in tests and seed scripts where a scope is not available and
  no email notification is required.

  Returns `{:ok, invitation}` on success or `{:error, changeset}` on failure.
  """
  @spec create_invitation(map()) :: {:ok, Invitation.t()} | {:error, Ecto.Changeset.t()}
  def create_invitation(attrs) when is_map(attrs) do
    expires_at = DateTime.add(DateTime.utc_now(:second), @invitation_validity_in_days, :day)

    full_attrs = Map.put_new(attrs, :expires_at, expires_at)

    case build_and_insert(full_attrs) do
      {:ok, {invitation, encoded_token}} ->
        {:ok, %{invitation | token: encoded_token}}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  # ---------------------------------------------------------------------------
  # Legacy API — kept for backward compatibility
  # ---------------------------------------------------------------------------

  @doc """
  Creates an invitation for the given account and delivers the acceptance email.

  The caller must provide a 1-arity url_fun that receives the raw encoded token
  and returns the full acceptance URL to include in the email. Only the hashed
  token is stored in the database.

  Returns `{:ok, invitation}` on success or `{:error, changeset}` on validation
  failure.
  """
  @spec create_invitation(Scope.t(), integer(), map(), (String.t() -> String.t())) ::
          {:ok, Invitation.t()} | {:error, Ecto.Changeset.t()}
  def create_invitation(%Scope{user: user} = _scope, account_id, attrs, url_fun)
      when is_function(url_fun, 1) do
    expires_at = DateTime.add(DateTime.utc_now(:second), @invitation_validity_in_days, :day)
    account = Repo.get!(Account, account_id)

    invitation_attrs =
      attrs
      |> Map.put(:expires_at, expires_at)
      |> Map.put(:account_id, account_id)
      |> Map.put(:invited_by_user_id, user.id)

    case build_and_insert(invitation_attrs) do
      {:ok, {invitation, encoded_token}} ->
        acceptance_url = url_fun.(encoded_token)
        _ = InvitationNotifier.deliver_invitation(invitation, account.name, acceptance_url)
        {:ok, invitation}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Creates an invitation record and returns it along with the encoded token.

  Does not send any email. Useful for contexts where the caller manages
  delivery separately (e.g., tests, background jobs).

  Returns `{:ok, {invitation, encoded_token}}` on success or
  `{:error, changeset}` on validation failure.
  """
  @spec build_invitation(map()) :: {:ok, {Invitation.t(), String.t()}} | {:error, Ecto.Changeset.t()}
  def build_invitation(attrs) do
    expires_at = DateTime.add(DateTime.utc_now(:second), @invitation_validity_in_days, :day)

    attrs
    |> Map.put(:expires_at, expires_at)
    |> build_and_insert()
  end

  # ---------------------------------------------------------------------------
  # Private helpers — token and changeset
  # ---------------------------------------------------------------------------

  defp normalize_email_key(%{recipient_email: email} = attrs) do
    attrs
    |> Map.delete(:recipient_email)
    |> Map.put(:email, email)
  end

  defp normalize_email_key(attrs), do: attrs

  defp to_atom_keys(attrs) when is_map(attrs) do
    Map.new(attrs, fn
      {key, value} when is_binary(key) -> {String.to_existing_atom(key), value}
      {key, value} -> {key, value}
    end)
  end

  defp insert_and_notify(changeset, encoded_token, account_name) do
    case InvitationRepository.create_invitation(changeset) do
      {:ok, invitation} ->
        acceptance_url = build_acceptance_url(encoded_token)
        _ = InvitationNotifier.deliver_invitation(invitation, account_name, acceptance_url)
        {:ok, invitation}

      {:error, _changeset} = error ->
        error
    end
  end

  defp build_and_insert(attrs) do
    {encoded_token, token_changeset} = Invitation.build_token(%Invitation{})

    case Repo.insert(apply_changeset(token_changeset, attrs)) do
      {:ok, invitation} -> {:ok, {invitation, encoded_token}}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp apply_changeset(token_changeset, attrs) do
    token_changeset
    |> Ecto.Changeset.cast(attrs, [
      :email,
      :role,
      :status,
      :expires_at,
      :accepted_at,
      :account_id,
      :invited_by_user_id
    ])
    |> Ecto.Changeset.validate_required([:email, :role])
    |> Ecto.Changeset.validate_format(:email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/,
      message: "must be a valid email address"
    )
    |> Ecto.Changeset.foreign_key_constraint(:account_id)
    |> Ecto.Changeset.foreign_key_constraint(:invited_by_user_id)
    |> Ecto.Changeset.unique_constraint(:token_hash)
  end

  # ---------------------------------------------------------------------------
  # Private helpers — authorization
  # ---------------------------------------------------------------------------

  defp authorize_invite(%Scope{user: user}, account_id) do
    query =
      from(m in AccountMember,
        where: m.user_id == ^user.id and m.account_id == ^account_id,
        select: m.role
      )

    case Repo.one(query) do
      role when role in [:owner, :admin] -> :ok
      _ -> {:error, :unauthorized}
    end
  end

  defp check_not_already_member(user_id, account_id) do
    if Repo.exists?(
         from(m in AccountMember,
           where: m.user_id == ^user_id and m.account_id == ^account_id
         )
       ) do
      {:error, :already_member}
    else
      :ok
    end
  end

  defp check_pending(%Invitation{status: :pending}), do: :ok
  defp check_pending(%Invitation{}), do: {:error, :not_pending}

  # ---------------------------------------------------------------------------
  # Private helpers — database operations
  # ---------------------------------------------------------------------------

  defp lookup_invitation(token_hash) do
    query =
      from i in Invitation,
        where: i.token_hash == ^token_hash,
        preload: [:account, :invited_by]

    case Repo.one(query) do
      nil ->
        {:error, :not_found}

      %Invitation{status: status} when status in [:accepted, :declined] ->
        {:error, :not_found}

      %Invitation{} = invitation ->
        check_invitation_expiry(invitation)
    end
  end

  defp check_invitation_expiry(%Invitation{expires_at: expires_at, inserted_at: inserted_at} = invitation) do
    now = DateTime.utc_now()
    inserted_at_dt = DateTime.from_naive!(inserted_at, "Etc/UTC")
    inserted_at_expiry = DateTime.add(inserted_at_dt, @invitation_validity_in_days, :day)

    expires_at_ok = DateTime.before?(now, expires_at)
    inserted_at_ok = DateTime.before?(now, inserted_at_expiry)

    if expires_at_ok and inserted_at_ok do
      {:ok, invitation}
    else
      {:error, :expired}
    end
  end

  defp build_acceptance_url(encoded_token) do
    base_url =
      Application.get_env(:metric_flow, MetricFlowWeb.Endpoint, [])
      |> Keyword.get(:url, [])
      |> Keyword.get(:host, "localhost")

    port =
      Application.get_env(:metric_flow, MetricFlowWeb.Endpoint, [])
      |> Keyword.get(:http, [])
      |> Keyword.get(:port, 4000)

    "http://#{base_url}:#{port}/invitations/#{encoded_token}"
  end
end
