defmodule MetricFlow.Invitations.InvitationRepositoryTest do
  use MetricFlow.DataCase, async: true

  alias MetricFlow.Invitations.{Invitation, InvitationRepository}
  alias MetricFlow.Users.Scope

  import MetricFlow.InvitationsFixtures
  import MetricFlow.UsersFixtures
  import MetricFlow.AccountsFixtures

  describe "create_invitation/2" do
    setup do
      user = user_fixture()
      account = account_with_owner_fixture(user)
      scope = %Scope{user: user, active_account_id: account.id}

      %{user: user, account: account, scope: scope}
    end

    test "creates invitation with valid attributes", %{scope: scope, user: user, account: account} do
      attrs = %{
        email: "invitee@example.com",
        role: :member,
        account_id: account.id,
        invited_by_id: user.id
      }

      assert {:ok, %Invitation{} = invitation} =
               InvitationRepository.create_invitation(scope, attrs)

      assert invitation.email == "invitee@example.com"
      assert invitation.role == :member
      assert invitation.account_id == account.id
      assert invitation.invited_by_id == user.id
      assert invitation.token
      assert invitation.expires_at
      assert is_nil(invitation.accepted_at)
      assert is_nil(invitation.cancelled_at)
    end

    test "returns error with invalid attributes", %{scope: scope, account: account} do
      attrs = %{email: "invalid", role: :invalid_role, account_id: account.id}

      assert {:error, changeset} = InvitationRepository.create_invitation(scope, attrs)
      assert %{email: ["has invalid format"]} = errors_on(changeset)
      assert %{role: ["is invalid"]} = errors_on(changeset)
    end
  end

  describe "get_invitation/2" do
    setup do
      user = user_fixture()
      account = account_with_owner_fixture(user)
      scope = %Scope{user: user, active_account_id: account.id}
      invitation = invitation_fixture(account, user)

      %{user: user, account: account, scope: scope, invitation: invitation}
    end

    test "returns invitation when found", %{scope: scope, invitation: invitation} do
      result = InvitationRepository.get_invitation(scope, invitation.id)
      assert result.id == invitation.id
      assert result.email == invitation.email
    end

    test "returns nil when invitation not found", %{scope: scope} do
      assert InvitationRepository.get_invitation(scope, 999) == nil
    end

    test "returns nil when scope has no active account" do
      scope = %Scope{user: user_fixture(), active_account_id: nil}
      assert InvitationRepository.get_invitation(scope, 1) == nil
    end
  end

  describe "get_invitation!/2" do
    setup do
      user = user_fixture()
      account = account_with_owner_fixture(user)
      scope = %Scope{user: user, active_account_id: account.id}
      invitation = invitation_fixture(account, user)

      %{user: user, account: account, scope: scope, invitation: invitation}
    end

    test "returns invitation when found", %{scope: scope, invitation: invitation} do
      result = InvitationRepository.get_invitation!(scope, invitation.id)
      assert result.id == invitation.id
    end

    test "raises when invitation not found", %{scope: scope} do
      assert_raise Ecto.NoResultsError, fn ->
        InvitationRepository.get_invitation!(scope, 999)
      end
    end

    test "raises when scope has no active account" do
      scope = %Scope{user: user_fixture(), active_account_id: nil}

      assert_raise Ecto.NoResultsError, fn ->
        InvitationRepository.get_invitation!(scope, 1)
      end
    end
  end

  describe "update_invitation/3" do
    setup do
      user = user_fixture()
      account = account_with_owner_fixture(user)
      scope = %Scope{user: user, active_account_id: account.id}
      invitation = invitation_fixture(account, user)

      %{user: user, account: account, scope: scope, invitation: invitation}
    end

    test "updates invitation with valid attributes", %{scope: scope, invitation: invitation} do
      attrs = %{email: "updated@example.com", role: :admin}

      assert {:ok, %Invitation{} = updated} =
               InvitationRepository.update_invitation(scope, invitation, attrs)

      assert updated.email == "updated@example.com"
      assert updated.role == :admin
    end

    test "returns error with invalid attributes", %{scope: scope, invitation: invitation} do
      attrs = %{email: "invalid", role: :invalid_role}

      assert {:error, changeset} =
               InvitationRepository.update_invitation(scope, invitation, attrs)

      assert %{email: ["has invalid format"]} = errors_on(changeset)
    end
  end

  describe "delete_invitation/2" do
    setup do
      user = user_fixture()
      account = account_with_owner_fixture(user)
      scope = %Scope{user: user, active_account_id: account.id}
      invitation = invitation_fixture(account, user)

      %{user: user, account: account, scope: scope, invitation: invitation}
    end

    test "deletes invitation", %{scope: scope, invitation: invitation} do
      assert {:ok, %Invitation{}} = InvitationRepository.delete_invitation(scope, invitation)
      assert InvitationRepository.get_invitation(scope, invitation.id) == nil
    end
  end

  describe "get_invitation_by_token/1" do
    setup do
      user = user_fixture()
      account = account_with_owner_fixture(user)
      invitation = invitation_fixture(account, user)

      %{invitation: invitation}
    end

    test "returns invitation when token matches", %{invitation: invitation} do
      result = InvitationRepository.get_invitation_by_token(invitation.token)
      assert result.id == invitation.id
    end

    test "returns nil when token doesn't match" do
      assert InvitationRepository.get_invitation_by_token("invalid_token") == nil
    end
  end

  describe "token_exists?/1" do
    setup do
      user = user_fixture()
      account = account_with_owner_fixture(user)
      invitation = invitation_fixture(account, user)

      %{invitation: invitation}
    end

    test "returns true when token exists", %{invitation: invitation} do
      assert InvitationRepository.token_exists?(invitation.token) == true
    end

    test "returns false when token doesn't exist" do
      assert InvitationRepository.token_exists?("nonexistent_token") == false
    end
  end

  describe "accept/2" do
    setup do
      user = user_fixture()
      account = account_with_owner_fixture(user)
      scope = %Scope{user: user, active_account_id: account.id}
      invitation = invitation_fixture(account, user)

      %{user: user, account: account, scope: scope, invitation: invitation}
    end

    test "accepts invitation", %{scope: scope, invitation: invitation} do
      assert {:ok, %Invitation{} = accepted} = InvitationRepository.accept(scope, invitation)
      assert accepted.accepted_at
      assert is_nil(accepted.cancelled_at)
    end
  end

  describe "cancel/2" do
    setup do
      user = user_fixture()
      account = account_with_owner_fixture(user)
      scope = %Scope{user: user, active_account_id: account.id}
      invitation = invitation_fixture(account, user)

      %{user: user, account: account, scope: scope, invitation: invitation}
    end

    test "cancels invitation", %{scope: scope, invitation: invitation} do
      assert {:ok, %Invitation{} = cancelled} = InvitationRepository.cancel(scope, invitation)
      assert cancelled.cancelled_at
      assert is_nil(cancelled.accepted_at)
    end
  end

  describe "by_email/2" do
    setup do
      user = user_fixture()
      account = account_with_owner_fixture(user)
      invitation = invitation_fixture(account, user, %{email: "test@example.com"})

      %{invitation: invitation}
    end

    test "filters by email", %{invitation: invitation} do
      query = from(i in Invitation) |> InvitationRepository.by_email("test@example.com")
      results = Repo.all(query)

      assert length(results) == 1
      assert hd(results).id == invitation.id
    end
  end

  describe "by_account/2" do
    setup do
      user = user_fixture()
      account1 = account_with_owner_fixture(user)
      account2 = account_with_owner_fixture(user)
      invitation1 = invitation_fixture(account1, user)
      invitation2 = invitation_fixture(account2, user)

      %{
        account1: account1,
        account2: account2,
        invitation1: invitation1,
        invitation2: invitation2
      }
    end

    test "filters by account", %{account1: account1, invitation1: invitation1} do
      query = from(i in Invitation) |> InvitationRepository.by_account(account1.id)
      results = Repo.all(query)

      assert length(results) == 1
      assert hd(results).id == invitation1.id
    end
  end

  describe "pending/1" do
    setup do
      user = user_fixture()
      account = account_with_owner_fixture(user)
      pending_invitation = invitation_fixture(account, user)
      accepted_invitation = invitation_fixture(account, user, %{accepted_at: DateTime.utc_now()})

      %{pending: pending_invitation, accepted: accepted_invitation}
    end

    test "filters pending invitations", %{pending: pending_invitation} do
      query = from(i in Invitation) |> InvitationRepository.pending()
      results = Repo.all(query)

      assert length(results) == 1
      assert hd(results).id == pending_invitation.id
    end
  end

  describe "not_expired/1" do
    setup do
      user = user_fixture()
      account = account_with_owner_fixture(user)
      valid_invitation = invitation_fixture(account, user)
      expired_invitation = expired_invitation_fixture(account, user)

      %{valid: valid_invitation, expired: expired_invitation}
    end

    test "filters non-expired invitations", %{valid: valid_invitation} do
      query = from(i in Invitation) |> InvitationRepository.not_expired()
      results = Repo.all(query)

      assert length(results) == 1
      assert hd(results).id == valid_invitation.id
    end
  end

  describe "expired/1" do
    setup do
      user = user_fixture()
      account = account_with_owner_fixture(user)
      valid_invitation = invitation_fixture(account, user)
      expired_invitation = expired_invitation_fixture(account, user)

      %{valid: valid_invitation, expired: expired_invitation}
    end

    test "filters expired invitations", %{expired: expired_invitation} do
      query = from(i in Invitation) |> InvitationRepository.expired()
      results = Repo.all(query)

      assert length(results) == 1
      assert hd(results).id == expired_invitation.id
    end
  end

  describe "cleanup_expired_invitations/1" do
    setup do
      user = user_fixture()
      account = account_with_owner_fixture(user)
      old_expired = expired_invitation_fixture(account, user)

      # Update to make it older than the cutoff
      Repo.update!(
        Invitation.changeset(old_expired, %{
          expires_at: DateTime.utc_now() |> DateTime.add(-8, :day)
        })
      )

      %{old_expired: old_expired}
    end

    test "cleans up old expired invitations", %{old_expired: old_expired} do
      {count, _} = InvitationRepository.cleanup_expired_invitations(7)

      assert count == 1
      assert Repo.get(Invitation, old_expired.id) == nil
    end
  end

  describe "count_pending_invitations/1" do
    setup do
      user = user_fixture()
      account = account_with_owner_fixture(user)
      scope = %Scope{user: user, active_account_id: account.id}

      invitation_fixture(account, user)
      invitation_fixture(account, user)
      accepted_invitation = invitation_fixture(account, user)
      InvitationRepository.accept(scope, accepted_invitation)

      %{scope: scope}
    end

    test "counts pending invitations", %{scope: scope} do
      count = InvitationRepository.count_pending_invitations(scope, scope.active_account_id)
      assert count == 2
    end

    test "returns 0 when scope has no active account" do
      scope = %Scope{user: user_fixture(), active_account_id: nil}
      assert InvitationRepository.count_pending_invitations(scope, nil) == 0
    end
  end
end
