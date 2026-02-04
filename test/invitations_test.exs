defmodule MetricFlow.InvitationsTest do
  use MetricFlowTest.DataCase

  alias MetricFlow.Invitations
  alias MetricFlow.Invitations.Invitation
  alias MetricFlow.Accounts.Member
  alias MetricFlow.Users.User

  import MetricFlowTest.AccountsFixtures
  import MetricFlowTest.UsersFixtures
  import MetricFlowTest.InvitationsFixtures

  describe "subscribe_invitations/1" do
    test "subscribes to invitation notifications for user" do
      user = user_fixture()
      scope = user_scope_fixture(user)

      assert :ok = Invitations.subscribe_invitations(scope)
    end
  end

  # Test URL builder - in production this would be provided by the web layer
  defp test_url_fun(token), do: "http://test.com/invitations/accept/#{token}"

  describe "invite_user/5" do
    setup do
      owner = user_fixture()
      account = account_with_owner_fixture(owner)
      scope = user_scope_fixture(owner, account)

      %{owner: owner, account: account, scope: scope}
    end

    test "creates invitation with valid attributes", %{scope: scope} do
      email = "invitee@example.com"
      role = :member

      assert {:ok, %Invitation{} = invitation} =
               Invitations.invite_user(scope, scope.active_account_id, email, role, &test_url_fun/1)

      assert invitation.email == email
      assert invitation.role == role
      assert invitation.account_id == scope.active_account_id
      assert invitation.invited_by_id == scope.user.id
      assert invitation.token != nil
      assert invitation.expires_at != nil
      assert is_nil(invitation.accepted_at)
      assert is_nil(invitation.cancelled_at)
    end

    test "returns error when user already has account access", %{scope: scope} do
      member = user_fixture()
      add_member_to_account(member, scope.active_account_id, :member)

      assert {:error, :user_already_member} =
               Invitations.invite_user(scope, scope.active_account_id, member.email, :member, &test_url_fun/1)
    end

    test "returns error when user lacks manage_members permission" do
      owner = user_fixture()
      account = account_with_owner_fixture(owner)

      # Create a regular member (not admin/owner)
      member = user_fixture()
      add_member_to_account(member, account.id, :member)
      member_scope = user_scope_fixture(member, account)

      assert {:error, :not_authorized} =
               Invitations.invite_user(member_scope, account.id, "test@example.com", :member, &test_url_fun/1)
    end

    test "returns error when scope has no active account" do
      user = user_fixture()
      # No active account
      scope = user_scope_fixture(user)

      assert {:error, :no_active_account} =
               Invitations.invite_user(scope, nil, "test@example.com", :member, &test_url_fun/1)
    end

    test "returns error with invalid email format", %{scope: scope} do
      assert {:error, %Ecto.Changeset{}} =
               Invitations.invite_user(scope, scope.active_account_id, "invalid-email", :member, &test_url_fun/1)
    end

    test "returns error with invalid role", %{scope: scope} do
      assert_raise FunctionClauseError, fn ->
        Invitations.invite_user(scope, scope.active_account_id, "test@example.com", :invalid_role, &test_url_fun/1)
      end
    end

    test "admin can invite users", %{account: account} do
      admin = user_fixture()
      add_member_to_account(admin, account.id, :admin)
      admin_scope = user_scope_fixture(admin, account)

      assert {:ok, %Invitation{}} =
               Invitations.invite_user(admin_scope, account.id, "test@example.com", :member, &test_url_fun/1)
    end
  end

  describe "accept_invitation/2" do
    setup do
      owner = user_fixture()
      account = account_with_owner_fixture(owner)
      invitation = invitation_fixture(account, owner)

      %{owner: owner, account: account, invitation: invitation}
    end

    test "accepts invitation for new user", %{invitation: invitation} do
      user_attrs = %{email: invitation.email, name: "New User"}

      assert {:ok, {%User{} = user, %Member{} = member}} =
               Invitations.accept_invitation(invitation.token, user_attrs)

      assert user.email == invitation.email
      assert member.user_id == user.id
      assert member.account_id == invitation.account_id
      assert member.role == invitation.role

      # Verify invitation is marked as accepted
      updated_invitation = Repo.get!(Invitation, invitation.id)
      assert updated_invitation.accepted_at != nil
    end

    test "accepts invitation for existing user", %{invitation: invitation} do
      existing_user = user_fixture(%{email: invitation.email})

      assert {:ok, {%User{} = user, %Member{} = member}} =
               Invitations.accept_invitation(invitation.token, %{})

      assert user.id == existing_user.id
      assert user.email == invitation.email
      assert member.user_id == user.id
      assert member.account_id == invitation.account_id
      assert member.role == invitation.role
    end

    test "returns error for invalid token" do
      assert {:error, :invalid_token} = Invitations.accept_invitation("invalid_token", %{})
    end

    test "returns error for expired invitation" do
      owner = user_fixture()
      account = account_with_owner_fixture(owner)
      expired_invitation = expired_invitation_fixture(account, owner)

      assert {:error, :expired_token} =
               Invitations.accept_invitation(expired_invitation.token, %{
                 email: expired_invitation.email
               })
    end

    test "returns error for already accepted invitation", %{invitation: invitation} do
      # Accept the invitation first
      Invitations.accept_invitation(invitation.token, %{email: invitation.email, name: "User"})

      # Try to accept again
      assert {:error, :invalid_token} =
               Invitations.accept_invitation(invitation.token, %{email: invitation.email})
    end

    test "returns error for already cancelled invitation" do
      owner = user_fixture()
      account = account_with_owner_fixture(owner)
      cancelled_invitation = cancelled_invitation_fixture(account, owner)

      assert {:error, :invalid_token} =
               Invitations.accept_invitation(cancelled_invitation.token, %{
                 email: cancelled_invitation.email
               })
    end

    test "returns error for email mismatch with existing user", %{invitation: invitation} do
      _existing_user = user_fixture(%{email: "different@example.com"})

      # Try to accept with different email
      assert {:error, :email_mismatch} =
               Invitations.accept_invitation(invitation.token, %{email: "different@example.com"})
    end
  end

  describe "list_pending_invitations/1" do
    setup do
      owner = user_fixture()
      account = account_with_owner_fixture(owner)
      scope = user_scope_fixture(owner, account)

      %{owner: owner, account: account, scope: scope}
    end

    test "returns pending invitations for account", %{
      scope: scope,
      account: account,
      owner: owner
    } do
      invitation1 = invitation_fixture(account, owner)
      invitation2 = invitation_fixture(account, owner)
      _expired_invitation = expired_invitation_fixture(account, owner)

      # Different account's invitation shouldn't be included
      other_account = account_fixture()
      _other_invitation = invitation_fixture(other_account, owner)

      invitations = Invitations.list_pending_invitations(scope, scope.active_account_id)

      assert length(invitations) == 2
      invitation_ids = Enum.map(invitations, & &1.id)
      assert invitation1.id in invitation_ids
      assert invitation2.id in invitation_ids
    end

    test "returns empty list when user lacks read access" do
      owner = user_fixture()
      account = account_with_owner_fixture(owner)
      _invitation = invitation_fixture(account, owner)

      # User not in account tries to list invitations
      other_user = user_fixture()
      other_scope = user_scope_fixture(other_user, account)

      assert [] = Invitations.list_pending_invitations(other_scope, other_scope.active_account_id)
    end
  end

  describe "list_user_invitations/1" do
    test "returns pending invitations for email across accounts" do
      email = "invited@example.com"

      owner1 = user_fixture()
      account1 = account_with_owner_fixture(owner1)
      invitation1 = invitation_fixture(account1, owner1, %{email: email})

      owner2 = user_fixture()
      account2 = account_with_owner_fixture(owner2)
      invitation2 = invitation_fixture(account2, owner2, %{email: email})

      # Different email shouldn't be included
      _other_invitation = invitation_fixture(account1, owner1, %{email: "other@example.com"})

      # Expired invitation shouldn't be included (use different account to avoid unique constraint)
      owner3 = user_fixture()
      account3 = account_with_owner_fixture(owner3)
      _expired_invitation = expired_invitation_fixture(account3, owner3, %{email: email})

      invitations = Invitations.list_user_invitations(email)

      assert length(invitations) == 2
      invitation_ids = Enum.map(invitations, & &1.id)
      assert invitation1.id in invitation_ids
      assert invitation2.id in invitation_ids
    end

    test "returns empty list when no invitations exist" do
      assert [] = Invitations.list_user_invitations("nonexistent@example.com")
    end
  end

  describe "cancel_invitation/2" do
    setup do
      owner = user_fixture()
      account = account_with_owner_fixture(owner)
      scope = user_scope_fixture(owner, account)
      invitation = invitation_fixture(account, owner)

      %{owner: owner, account: account, scope: scope, invitation: invitation}
    end

    test "cancels invitation successfully", %{scope: scope, invitation: invitation} do
      assert {:ok, %Invitation{} = cancelled_invitation} =
               Invitations.cancel_invitation(scope, scope.active_account_id, invitation.id)

      assert cancelled_invitation.cancelled_at != nil
      assert cancelled_invitation.id == invitation.id
    end

    test "returns error when invitation not found", %{scope: scope} do
      assert {:error, :not_found} =
               Invitations.cancel_invitation(scope, scope.active_account_id, 999_999)
    end

    test "returns error when user lacks manage_members permission" do
      owner = user_fixture()
      account = account_with_owner_fixture(owner)
      invitation = invitation_fixture(account, owner)

      # Regular member tries to cancel invitation
      member = user_fixture()
      add_member_to_account(member, account.id, :member)
      member_scope = user_scope_fixture(member, account)

      assert {:error, :not_authorized} =
               Invitations.cancel_invitation(member_scope, account.id, invitation.id)
    end

    test "returns error when no active account" do
      user = user_fixture()
      scope = user_scope_fixture(user)

      assert {:error, :no_active_account} = Invitations.cancel_invitation(scope, 1)
    end

    test "admin can cancel invitations", %{account: account, invitation: invitation} do
      admin = user_fixture()
      add_member_to_account(admin, account.id, :admin)
      admin_scope = user_scope_fixture(admin, account)

      assert {:ok, %Invitation{}} =
               Invitations.cancel_invitation(admin_scope, account.id, invitation.id)
    end
  end

  describe "get_invitation_by_token/1" do
    test "returns invitation for valid token" do
      owner = user_fixture()
      account = account_with_owner_fixture(owner)
      invitation = invitation_fixture(account, owner)

      assert %Invitation{} = result = Invitations.get_invitation_by_token(invitation.token)
      assert result.id == invitation.id
    end

    test "returns nil for invalid token" do
      assert nil == Invitations.get_invitation_by_token("invalid_token")
    end
  end

  describe "cleanup_expired_invitations/0" do
    test "cleans up expired invitations" do
      owner = user_fixture()
      account = account_with_owner_fixture(owner)

      # Create some expired invitations
      _expired1 = expired_invitation_fixture(account, owner)
      _expired2 = expired_invitation_fixture(account, owner)

      # Create a current invitation
      current = invitation_fixture(account, owner)

      assert :ok = Invitations.cleanup_expired_invitations()

      # Current invitation should still exist
      assert Repo.get(Invitation, current.id)
    end
  end

  # Helper functions
  defp add_member_to_account(user, account_id, role) do
    %Member{}
    |> Member.changeset(%{user_id: user.id, account_id: account_id, role: role})
    |> Repo.insert!()
  end
end
