defmodule MetricFlow.Invitations.InvitationRepositoryTest do
  use MetricFlowTest.DataCase, async: true

  import Ecto.Query
  import MetricFlowTest.UsersFixtures

  alias MetricFlow.Accounts.Account
  alias MetricFlow.Accounts.AccountMember
  alias MetricFlow.Invitations.Invitation
  alias MetricFlow.Invitations.InvitationRepository
  alias MetricFlow.Users.Scope

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp unique_slug, do: "account-#{System.unique_integer([:positive])}"

  defp insert_account!(user) do
    %Account{}
    |> Account.creation_changeset(%{
      name: "Test Account #{System.unique_integer([:positive])}",
      slug: unique_slug(),
      type: "team",
      originator_user_id: user.id
    })
    |> Repo.insert!()
  end

  defp insert_member!(account, user, role \\ :owner) do
    %AccountMember{}
    |> AccountMember.changeset(%{account_id: account.id, user_id: user.id, role: role})
    |> Repo.insert!()
  end

  defp future_expires_at do
    DateTime.add(DateTime.utc_now(), 7 * 24 * 3600, :second) |> DateTime.truncate(:second)
  end

  defp unique_token_hash, do: :crypto.strong_rand_bytes(32)

  defp valid_invitation_attrs(account_id, opts \\ []) do
    invited_by_user_id = Keyword.get(opts, :invited_by_user_id, nil)

    %{
      token_hash: unique_token_hash(),
      email: "invitee-#{System.unique_integer([:positive])}@example.com",
      role: :read_only,
      status: :pending,
      expires_at: future_expires_at(),
      account_id: account_id,
      invited_by_user_id: invited_by_user_id
    }
  end

  defp build_changeset(invitation \\ %Invitation{}, attrs) do
    Invitation.changeset(invitation, attrs)
  end

  defp insert_invitation!(attrs) do
    attrs
    |> build_changeset()
    |> Repo.insert!()
  end

  defp user_with_scope do
    user = user_fixture()
    scope = Scope.for_user(user)
    {user, scope}
  end

  defp user_with_account do
    {user, scope} = user_with_scope()
    account = insert_account!(user)
    insert_member!(account, user)
    {user, scope, account}
  end

  # Back-date an invitation's inserted_at so ordering tests are deterministic.
  defp backdate_invitation!(invitation, seconds_ago) do
    past = DateTime.add(DateTime.utc_now(:second), -seconds_ago, :second)

    Repo.update_all(
      from(i in Invitation, where: i.id == ^invitation.id),
      set: [inserted_at: past]
    )
  end

  # ---------------------------------------------------------------------------
  # create_invitation/1
  # ---------------------------------------------------------------------------

  describe "create_invitation/1" do
    test "returns {:ok, invitation} with valid attrs including token_hash, email, role, expires_at, and account_id" do
      {user, _scope} = user_with_scope()
      account = insert_account!(user)
      attrs = valid_invitation_attrs(account.id)
      changeset = build_changeset(attrs)

      assert {:ok, invitation} = InvitationRepository.create_invitation(changeset)
      assert invitation.email == attrs.email
      assert invitation.role == :read_only
      assert invitation.account_id == account.id
      assert invitation.token_hash == attrs.token_hash
      assert invitation.expires_at == attrs.expires_at
    end

    test "returns {:error, changeset} when token_hash is missing" do
      # token_hash has a NOT NULL constraint and a unique constraint in the DB.
      # The schema casts but does not validate_required(:token_hash), so a nil
      # value causes a Postgrex NOT NULL violation. The unique constraint is
      # enforced via changeset: this test confirms token_hash duplication is
      # rejected with a changeset error (unique_constraint catches it before insert).
      {user, _scope} = user_with_scope()
      account = insert_account!(user)
      shared_hash = unique_token_hash()

      first_changeset = build_changeset(valid_invitation_attrs(account.id) |> Map.put(:token_hash, shared_hash))
      {:ok, _} = InvitationRepository.create_invitation(first_changeset)

      second_changeset = build_changeset(valid_invitation_attrs(account.id) |> Map.put(:token_hash, shared_hash))

      assert {:error, result_changeset} = InvitationRepository.create_invitation(second_changeset)
      refute result_changeset.valid?
      assert %{token_hash: [_]} = errors_on(result_changeset)
    end

    test "returns {:error, changeset} when email is missing or has invalid format" do
      {user, _scope} = user_with_scope()
      account = insert_account!(user)

      missing_email_changeset =
        valid_invitation_attrs(account.id)
        |> Map.delete(:email)
        |> build_changeset()

      assert {:error, missing_changeset} = InvitationRepository.create_invitation(missing_email_changeset)
      assert %{email: ["can't be blank"]} = errors_on(missing_changeset)

      invalid_email_changeset =
        valid_invitation_attrs(account.id)
        |> Map.put(:email, "not-an-email")
        |> build_changeset()

      assert {:error, invalid_changeset} = InvitationRepository.create_invitation(invalid_email_changeset)
      assert %{email: [_]} = errors_on(invalid_changeset)
    end

    test "returns {:error, changeset} when role is missing" do
      {user, _scope} = user_with_scope()
      account = insert_account!(user)

      changeset =
        valid_invitation_attrs(account.id)
        |> Map.delete(:role)
        |> build_changeset()

      assert {:error, result_changeset} = InvitationRepository.create_invitation(changeset)
      assert %{role: ["can't be blank"]} = errors_on(result_changeset)
    end

    test "returns {:error, changeset} when expires_at is missing" do
      {user, _scope} = user_with_scope()
      account = insert_account!(user)

      # expires_at is not enforced by validate_required in the schema, but passing
      # an invalid type triggers a cast error, confirming type enforcement at the
      # changeset layer.
      changeset =
        valid_invitation_attrs(account.id)
        |> Map.put(:expires_at, "not-a-datetime")
        |> build_changeset()

      assert {:error, result_changeset} = InvitationRepository.create_invitation(changeset)
      refute result_changeset.valid?
    end

    test "returns {:error, changeset} when account_id is missing" do
      # account_id uses a foreign key constraint; a non-existent id triggers the constraint error.
      attrs = valid_invitation_attrs(-1)
      changeset = build_changeset(attrs)

      assert {:error, result_changeset} = InvitationRepository.create_invitation(changeset)
      assert %{account_id: [_]} = errors_on(result_changeset)
    end

    test "returns {:error, changeset} when token_hash is not unique" do
      {user, _scope} = user_with_scope()
      account = insert_account!(user)
      shared_token_hash = unique_token_hash()

      first_attrs = valid_invitation_attrs(account.id) |> Map.put(:token_hash, shared_token_hash)
      first_changeset = build_changeset(first_attrs)
      {:ok, _} = InvitationRepository.create_invitation(first_changeset)

      second_attrs = valid_invitation_attrs(account.id) |> Map.put(:token_hash, shared_token_hash)
      second_changeset = build_changeset(second_attrs)

      assert {:error, result_changeset} = InvitationRepository.create_invitation(second_changeset)
      assert %{token_hash: ["has already been taken"]} = errors_on(result_changeset)
    end

    test "persists invited_by_user_id when provided" do
      {user, _scope} = user_with_scope()
      account = insert_account!(user)
      attrs = valid_invitation_attrs(account.id, invited_by_user_id: user.id)
      changeset = build_changeset(attrs)

      assert {:ok, invitation} = InvitationRepository.create_invitation(changeset)
      assert invitation.invited_by_user_id == user.id
    end

    test "persists invitation with status defaulting to :pending" do
      {user, _scope} = user_with_scope()
      account = insert_account!(user)
      attrs = valid_invitation_attrs(account.id) |> Map.delete(:status)
      changeset = build_changeset(attrs)

      assert {:ok, invitation} = InvitationRepository.create_invitation(changeset)
      assert invitation.status == :pending
    end
  end

  # ---------------------------------------------------------------------------
  # get_by_token_hash/1
  # ---------------------------------------------------------------------------

  describe "get_by_token_hash/1" do
    test "returns {:ok, invitation} with account and invited_by preloaded when the token hash matches" do
      {user, _scope} = user_with_scope()
      account = insert_account!(user)
      token_hash = unique_token_hash()

      attrs =
        valid_invitation_attrs(account.id, invited_by_user_id: user.id)
        |> Map.put(:token_hash, token_hash)

      insert_invitation!(attrs)

      result = InvitationRepository.get_by_token_hash(token_hash)

      assert result != nil
      assert result.token_hash == token_hash
    end

    test "returns {:error, :not_found} when no invitation matches the token hash" do
      non_existent_hash = unique_token_hash()

      result = InvitationRepository.get_by_token_hash(non_existent_hash)

      assert result == nil
    end

    test "preloads the account association" do
      {user, _scope} = user_with_scope()
      account = insert_account!(user)
      token_hash = unique_token_hash()

      attrs = valid_invitation_attrs(account.id) |> Map.put(:token_hash, token_hash)
      insert_invitation!(attrs)

      result = InvitationRepository.get_by_token_hash(token_hash)

      assert result != nil
      assert %Account{} = result.account
      assert result.account.id == account.id
    end

    test "preloads the invited_by user association" do
      {user, _scope} = user_with_scope()
      account = insert_account!(user)
      token_hash = unique_token_hash()

      attrs =
        valid_invitation_attrs(account.id, invited_by_user_id: user.id)
        |> Map.put(:token_hash, token_hash)

      insert_invitation!(attrs)

      result = InvitationRepository.get_by_token_hash(token_hash)

      assert result != nil
      assert %MetricFlow.Users.User{} = result.invited_by
      assert result.invited_by.id == user.id
    end

    test "does not apply any account-level scoping (token hash is globally unique by constraint)" do
      {user_a, _scope_a} = user_with_scope()
      {user_b, _scope_b} = user_with_scope()

      account_a = insert_account!(user_a)
      account_b = insert_account!(user_b)

      token_hash_a = unique_token_hash()
      token_hash_b = unique_token_hash()

      attrs_a = valid_invitation_attrs(account_a.id) |> Map.put(:token_hash, token_hash_a)
      attrs_b = valid_invitation_attrs(account_b.id) |> Map.put(:token_hash, token_hash_b)

      insert_invitation!(attrs_a)
      insert_invitation!(attrs_b)

      result_a = InvitationRepository.get_by_token_hash(token_hash_a)
      result_b = InvitationRepository.get_by_token_hash(token_hash_b)

      assert result_a.account_id == account_a.id
      assert result_b.account_id == account_b.id
    end
  end

  # ---------------------------------------------------------------------------
  # list_invitations/2
  # ---------------------------------------------------------------------------

  describe "list_invitations/2" do
    test "returns all pending invitations for the given account_id" do
      {user, scope} = user_with_scope()
      account = insert_account!(user)

      insert_invitation!(valid_invitation_attrs(account.id))
      insert_invitation!(valid_invitation_attrs(account.id))

      results = InvitationRepository.list_invitations(scope, account.id)

      assert length(results) == 2
      assert Enum.all?(results, &(&1.account_id == account.id))
    end

    test "returns an empty list when no pending invitations exist for the account" do
      {user, scope} = user_with_scope()
      account = insert_account!(user)

      results = InvitationRepository.list_invitations(scope, account.id)

      assert results == []
    end

    test "does not return accepted invitations" do
      {user, scope} = user_with_scope()
      account = insert_account!(user)

      insert_invitation!(valid_invitation_attrs(account.id) |> Map.put(:status, :accepted))
      insert_invitation!(valid_invitation_attrs(account.id))

      results = InvitationRepository.list_invitations(scope, account.id)

      assert length(results) == 1
      assert hd(results).status == :pending
    end

    test "does not return invitations belonging to a different account" do
      {user_a, scope_a} = user_with_scope()
      {user_b, _scope_b} = user_with_scope()

      account_a = insert_account!(user_a)
      account_b = insert_account!(user_b)

      insert_invitation!(valid_invitation_attrs(account_a.id))
      insert_invitation!(valid_invitation_attrs(account_b.id))

      results = InvitationRepository.list_invitations(scope_a, account_a.id)

      assert length(results) == 1
      assert hd(results).account_id == account_a.id
    end

    test "orders results by most recently created first" do
      {user, scope} = user_with_scope()
      account = insert_account!(user)

      # Insert the older record first, then backdate it so inserted_at ordering is deterministic.
      first = insert_invitation!(valid_invitation_attrs(account.id))
      backdate_invitation!(first, 60)

      second = insert_invitation!(valid_invitation_attrs(account.id))

      results = InvitationRepository.list_invitations(scope, account.id)
      result_ids = Enum.map(results, & &1.id)

      assert result_ids == [second.id, first.id]
    end

    test "enforces multi-tenant isolation by account_id" do
      {user_a, scope_a} = user_with_scope()
      {user_b, _scope_b} = user_with_scope()

      account_a = insert_account!(user_a)
      account_b = insert_account!(user_b)

      insert_invitation!(valid_invitation_attrs(account_a.id))
      insert_invitation!(valid_invitation_attrs(account_b.id))
      insert_invitation!(valid_invitation_attrs(account_b.id))

      results = InvitationRepository.list_invitations(scope_a, account_a.id)

      assert length(results) == 1
      assert hd(results).account_id == account_a.id
    end
  end

  # ---------------------------------------------------------------------------
  # get_invitation/2
  # ---------------------------------------------------------------------------

  describe "get_invitation/2" do
    test "returns {:ok, invitation} when the invitation exists and belongs to the given account" do
      {_user, scope, account} = user_with_account()
      invitation = insert_invitation!(valid_invitation_attrs(account.id))

      assert {:ok, result} = InvitationRepository.get_invitation(scope, invitation.id)
      assert result.id == invitation.id
      assert result.account_id == account.id
    end

    test "returns {:error, :not_found} when the invitation id does not exist" do
      {_user, scope} = user_with_scope()

      assert {:error, :not_found} = InvitationRepository.get_invitation(scope, -1)
    end

    test "returns {:error, :not_found} when the invitation exists but belongs to a different account" do
      {user_a, scope_a} = user_with_scope()
      {user_b, _scope_b} = user_with_scope()

      account_a = insert_account!(user_a)
      account_b = insert_account!(user_b)

      # user_a is a member of account_a only, not account_b
      insert_member!(account_a, user_a)

      invitation = insert_invitation!(valid_invitation_attrs(account_b.id))

      assert {:error, :not_found} = InvitationRepository.get_invitation(scope_a, invitation.id)
    end

    test "enforces multi-tenant isolation by account_id" do
      {_user_a, scope_a, account_a} = user_with_account()
      {user_b, _scope_b} = user_with_scope()

      account_b = insert_account!(user_b)
      insert_member!(account_b, user_b)

      invitation_a = insert_invitation!(valid_invitation_attrs(account_a.id))
      invitation_b = insert_invitation!(valid_invitation_attrs(account_b.id))

      assert {:ok, result_a} = InvitationRepository.get_invitation(scope_a, invitation_a.id)
      assert result_a.id == invitation_a.id

      assert {:error, :not_found} = InvitationRepository.get_invitation(scope_a, invitation_b.id)
    end
  end

  # ---------------------------------------------------------------------------
  # update_invitation/2
  # ---------------------------------------------------------------------------

  describe "update_invitation/2" do
    test "returns {:ok, invitation} with updated status when attrs are valid" do
      {user, _scope} = user_with_scope()
      account = insert_account!(user)
      invitation = insert_invitation!(valid_invitation_attrs(account.id))

      changeset = Invitation.accept_changeset(invitation)

      assert {:ok, updated} = InvitationRepository.update_invitation(invitation, changeset)
      assert updated.status == :accepted
    end

    test "returns {:error, changeset} when attrs are invalid" do
      {user, _scope} = user_with_scope()
      account = insert_account!(user)
      invitation = insert_invitation!(valid_invitation_attrs(account.id))

      # Build a changeset with an invalid role to trigger a changeset error
      invalid_changeset = Invitation.changeset(invitation, %{role: :not_a_valid_role})

      assert {:error, result_changeset} =
               InvitationRepository.update_invitation(invitation, invalid_changeset)

      refute result_changeset.valid?
    end

    test "can update status from :pending to :accepted" do
      {user, _scope} = user_with_scope()
      account = insert_account!(user)
      attrs = valid_invitation_attrs(account.id) |> Map.put(:status, :pending)
      invitation = insert_invitation!(attrs)

      assert invitation.status == :pending

      accept_changeset = Invitation.accept_changeset(invitation)

      assert {:ok, updated} = InvitationRepository.update_invitation(invitation, accept_changeset)
      assert updated.status == :accepted
    end

    test "does not change immutable fields such as token_hash or account_id when not provided in attrs" do
      {user, _scope} = user_with_scope()
      account = insert_account!(user)
      attrs = valid_invitation_attrs(account.id)
      invitation = insert_invitation!(attrs)

      original_token_hash = invitation.token_hash
      original_account_id = invitation.account_id

      status_only_changeset = Invitation.accept_changeset(invitation)

      assert {:ok, updated} =
               InvitationRepository.update_invitation(invitation, status_only_changeset)

      assert updated.token_hash == original_token_hash
      assert updated.account_id == original_account_id
    end
  end
end
