defmodule MetricFlow.InvitationsTest do
  use MetricFlowTest.DataCase, async: true

  import Swoosh.TestAssertions
  import MetricFlowTest.UsersFixtures

  alias MetricFlow.Accounts.Account
  alias MetricFlow.Accounts.AccountMember
  alias MetricFlow.Invitations
  alias MetricFlow.Invitations.Invitation
  alias MetricFlow.Repo
  alias MetricFlow.Users.Scope

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp unique_slug, do: "account-#{System.unique_integer([:positive])}"

  defp user_fixture_with_scope do
    user = user_fixture()
    scope = Scope.for_user(user)
    {user, scope}
  end

  defp insert_account!(user, overrides \\ %{}) do
    defaults = %{
      name: "Test Account #{System.unique_integer([:positive])}",
      slug: unique_slug(),
      type: "team",
      originator_user_id: user.id
    }

    %Account{}
    |> Account.creation_changeset(Map.merge(defaults, overrides))
    |> Repo.insert!()
  end

  defp insert_member!(account, user, role) do
    %AccountMember{}
    |> AccountMember.changeset(%{account_id: account.id, user_id: user.id, role: role})
    |> Repo.insert!()
  end

  # Creates a team account and adds the scope's user as owner.
  defp account_fixture(scope, overrides \\ %{}) do
    account = insert_account!(scope.user, overrides)
    insert_member!(account, scope.user, :owner)
    account
  end

  # Creates a team account and adds the given user with the given role.
  defp account_fixture_with_member(user, role) do
    account = insert_account!(user)
    insert_member!(account, user, role)
    account
  end

  # Builds a pending invitation without sending an email.
  # Returns {invitation, encoded_token}.
  defp pending_invitation_fixture(account_id, invited_by_user_id, overrides \\ %{}) do
    attrs =
      Map.merge(
        %{
          email: "invitee-#{System.unique_integer([:positive])}@example.com",
          role: :read_only,
          account_id: account_id,
          invited_by_user_id: invited_by_user_id
        },
        overrides
      )

    {:ok, {invitation, encoded_token}} = Invitations.build_invitation(attrs)
    {invitation, encoded_token}
  end

  # Builds a pending invitation and immediately marks it accepted in the DB.
  # Returns {invitation, encoded_token}.
  defp accepted_invitation_fixture(account_id, invited_by_user_id) do
    {invitation, encoded_token} =
      pending_invitation_fixture(account_id, invited_by_user_id, %{
        email: "accepted-#{System.unique_integer([:positive])}@example.com"
      })

    invitation |> Invitation.accept_changeset() |> Repo.update!()
    {invitation, encoded_token}
  end

  # Builds a pending invitation and sets its expiry to 8 days in the past.
  # Returns {invitation, encoded_token}.
  defp expired_invitation_fixture(account_id, invited_by_user_id) do
    {invitation, encoded_token} =
      pending_invitation_fixture(account_id, invited_by_user_id, %{
        email: "expired-#{System.unique_integer([:positive])}@example.com"
      })

    past = DateTime.add(DateTime.utc_now(:second), -8, :day)
    invitation |> Ecto.Changeset.change(expires_at: past) |> Repo.update!()
    {invitation, encoded_token}
  end

  # Drains setup emails (registration, magic-link) from the process mailbox so
  # that subsequent assert_email_sent calls target only invitation emails.
  defp drain_emails do
    receive do
      {:email, _} -> drain_emails()
    after
      0 -> :ok
    end
  end

  # ---------------------------------------------------------------------------
  # send_invitation/3
  # ---------------------------------------------------------------------------

  describe "send_invitation/3" do
    test "returns ok tuple with Invitation struct on success for an account owner" do
      {user, _scope} = user_fixture_with_scope()
      account = account_fixture_with_member(user, :owner)
      scope = Scope.for_user(user)
      drain_emails()

      assert {:ok, %Invitation{}} =
               Invitations.send_invitation(
                 scope,
                 account.id,
                 %{email: "invitee@example.com", role: :read_only}
               )
    end

    test "returns ok tuple with Invitation struct on success for an account admin" do
      {user, _scope} = user_fixture_with_scope()
      account = account_fixture_with_member(user, :admin)
      scope = Scope.for_user(user)
      drain_emails()

      assert {:ok, %Invitation{}} =
               Invitations.send_invitation(
                 scope,
                 account.id,
                 %{email: "invitee@example.com", role: :read_only}
               )
    end

    test "sets recipient_email from attrs" do
      {user, _scope} = user_fixture_with_scope()
      account = account_fixture_with_member(user, :owner)
      scope = Scope.for_user(user)
      drain_emails()

      {:ok, invitation} =
        Invitations.send_invitation(
          scope,
          account.id,
          %{email: "recipient@example.com", role: :read_only}
        )

      assert invitation.email == "recipient@example.com"
    end

    test "sets role from attrs" do
      {user, _scope} = user_fixture_with_scope()
      account = account_fixture_with_member(user, :owner)
      scope = Scope.for_user(user)
      drain_emails()

      {:ok, invitation} =
        Invitations.send_invitation(
          scope,
          account.id,
          %{email: "role@example.com", role: :account_manager}
        )

      assert invitation.role == :account_manager
    end

    test "sets invited_by_user_id from scope user" do
      {user, _scope} = user_fixture_with_scope()
      account = account_fixture_with_member(user, :owner)
      scope = Scope.for_user(user)
      drain_emails()

      {:ok, invitation} =
        Invitations.send_invitation(
          scope,
          account.id,
          %{email: "by@example.com", role: :read_only}
        )

      assert invitation.invited_by_user_id == user.id
    end

    test "sets expires_at to approximately 7 days from now" do
      {user, _scope} = user_fixture_with_scope()
      account = account_fixture_with_member(user, :owner)
      scope = Scope.for_user(user)
      drain_emails()
      before_call = DateTime.utc_now()

      {:ok, invitation} =
        Invitations.send_invitation(
          scope,
          account.id,
          %{email: "expires@example.com", role: :read_only}
        )

      assert DateTime.after?(invitation.expires_at, DateTime.add(before_call, 6, :day))
      assert DateTime.before?(invitation.expires_at, DateTime.add(before_call, 8, :day))
    end

    test "generates a non-nil token on the invitation record" do
      {user, _scope} = user_fixture_with_scope()
      account = account_fixture_with_member(user, :owner)
      scope = Scope.for_user(user)
      drain_emails()

      {:ok, invitation} =
        Invitations.send_invitation(
          scope,
          account.id,
          %{email: "token@example.com", role: :read_only}
        )

      assert invitation.token_hash != nil
    end

    test "delivers an invitation email to the recipient_email address" do
      {user, _scope} = user_fixture_with_scope()
      account = account_fixture_with_member(user, :owner)
      scope = Scope.for_user(user)
      recipient = "deliver-#{System.unique_integer([:positive])}@example.com"
      drain_emails()

      Invitations.send_invitation(scope, account.id, %{email: recipient, role: :read_only})

      assert_email_sent(to: recipient)
    end

    test "returns error :unauthorized when caller role is :account_manager" do
      {user, _scope} = user_fixture_with_scope()
      account = account_fixture_with_member(user, :account_manager)
      scope = Scope.for_user(user)

      assert {:error, :unauthorized} =
               Invitations.send_invitation(
                 scope,
                 account.id,
                 %{email: "invitee@example.com", role: :read_only}
               )
    end

    test "returns error :unauthorized when caller role is :read_only" do
      {user, _scope} = user_fixture_with_scope()
      account = account_fixture_with_member(user, :read_only)
      scope = Scope.for_user(user)

      assert {:error, :unauthorized} =
               Invitations.send_invitation(
                 scope,
                 account.id,
                 %{email: "invitee@example.com", role: :read_only}
               )
    end

    test "returns error changeset when recipient_email is blank" do
      {user, _scope} = user_fixture_with_scope()
      account = account_fixture_with_member(user, :owner)
      scope = Scope.for_user(user)

      assert {:error, changeset} =
               Invitations.send_invitation(scope, account.id, %{role: :read_only})

      assert changeset.errors[:email] != nil
    end

    test "returns error changeset when recipient_email format is invalid" do
      {user, _scope} = user_fixture_with_scope()
      account = account_fixture_with_member(user, :owner)
      scope = Scope.for_user(user)

      assert {:error, changeset} =
               Invitations.send_invitation(
                 scope,
                 account.id,
                 %{email: "not-an-email", role: :read_only}
               )

      assert changeset.errors[:email] != nil
    end

    test "returns error changeset when role is not a valid enum value" do
      {user, _scope} = user_fixture_with_scope()
      account = account_fixture_with_member(user, :owner)
      scope = Scope.for_user(user)

      assert {:error, changeset} =
               Invitations.send_invitation(
                 scope,
                 account.id,
                 %{email: "invitee@example.com", role: :super_admin}
               )

      assert changeset.errors[:role] != nil
    end
  end

  # ---------------------------------------------------------------------------
  # get_invitation_by_token/1
  # ---------------------------------------------------------------------------

  describe "get_invitation_by_token/1" do
    test "returns ok tuple with preloaded Invitation for a valid pending non-expired token" do
      {user, scope} = user_fixture_with_scope()
      account = account_fixture(scope)
      {_inv, encoded_token} = pending_invitation_fixture(account.id, user.id)

      assert {:ok, %Invitation{}} = Invitations.get_invitation_by_token(encoded_token)
    end

    test "preloads the account association on the returned invitation" do
      {user, scope} = user_fixture_with_scope()
      account = account_fixture(scope)
      {_inv, encoded_token} = pending_invitation_fixture(account.id, user.id)

      {:ok, fetched} = Invitations.get_invitation_by_token(encoded_token)

      assert Ecto.assoc_loaded?(fetched.account)
      assert %Account{} = fetched.account
      assert fetched.account.id == account.id
    end

    test "preloads the invited_by user association on the returned invitation" do
      {user, scope} = user_fixture_with_scope()
      account = account_fixture(scope)
      {_inv, encoded_token} = pending_invitation_fixture(account.id, user.id)

      {:ok, fetched} = Invitations.get_invitation_by_token(encoded_token)

      assert fetched.invited_by_user_id == user.id
    end

    test "returns error :not_found when token does not match any invitation" do
      bogus_token = Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)

      assert {:error, :not_found} = Invitations.get_invitation_by_token(bogus_token)
    end

    test "returns error :not_found when invitation status is :accepted" do
      {user, scope} = user_fixture_with_scope()
      account = account_fixture(scope)
      {_inv, encoded_token} = accepted_invitation_fixture(account.id, user.id)

      assert {:error, :not_found} = Invitations.get_invitation_by_token(encoded_token)
    end

    test "returns error :not_found when invitation status is :declined" do
      {user, scope} = user_fixture_with_scope()
      account = account_fixture(scope)
      {invitation, encoded_token} = pending_invitation_fixture(account.id, user.id)

      invitation |> Invitation.decline_changeset() |> Repo.update!()

      assert {:error, :not_found} = Invitations.get_invitation_by_token(encoded_token)
    end

    test "returns error :expired when invitation expires_at is in the past" do
      {user, scope} = user_fixture_with_scope()
      account = account_fixture(scope)
      {_inv, encoded_token} = expired_invitation_fixture(account.id, user.id)

      assert {:error, :expired} = Invitations.get_invitation_by_token(encoded_token)
    end
  end

  # ---------------------------------------------------------------------------
  # accept_invitation/2
  # ---------------------------------------------------------------------------

  describe "accept_invitation/2" do
    test "returns ok tuple with AccountMember on success" do
      {owner, scope} = user_fixture_with_scope()
      account = account_fixture(scope)
      invitee = user_fixture()
      invitee_scope = Scope.for_user(invitee)
      {_inv, encoded_token} = pending_invitation_fixture(account.id, owner.id, %{email: invitee.email})

      assert {:ok, %AccountMember{}} = Invitations.accept_invitation(invitee_scope, encoded_token)
    end

    test "AccountMember has the role specified in the invitation" do
      {owner, scope} = user_fixture_with_scope()
      account = account_fixture(scope)
      invitee = user_fixture()
      invitee_scope = Scope.for_user(invitee)

      {_inv, encoded_token} =
        pending_invitation_fixture(account.id, owner.id, %{email: invitee.email, role: :account_manager})

      {:ok, _member} = Invitations.accept_invitation(invitee_scope, encoded_token)

      stored = Repo.get_by!(AccountMember, account_id: account.id, user_id: invitee.id)
      assert stored.role == :account_manager
    end

    test "AccountMember belongs to the invitation's account" do
      {owner, scope} = user_fixture_with_scope()
      account = account_fixture(scope)
      invitee = user_fixture()
      invitee_scope = Scope.for_user(invitee)
      {_inv, encoded_token} = pending_invitation_fixture(account.id, owner.id, %{email: invitee.email})

      {:ok, _member} = Invitations.accept_invitation(invitee_scope, encoded_token)

      stored = Repo.get_by(AccountMember, account_id: account.id, user_id: invitee.id)
      assert stored != nil
      assert stored.account_id == account.id
    end

    test "marks the invitation status as :accepted" do
      {owner, scope} = user_fixture_with_scope()
      account = account_fixture(scope)
      invitee = user_fixture()
      invitee_scope = Scope.for_user(invitee)
      {invitation, encoded_token} = pending_invitation_fixture(account.id, owner.id, %{email: invitee.email})

      {:ok, _member} = Invitations.accept_invitation(invitee_scope, encoded_token)

      updated = Repo.get!(Invitation, invitation.id)
      assert updated.status == :accepted
    end

    test "sets accepted_at on the invitation record" do
      {owner, scope} = user_fixture_with_scope()
      account = account_fixture(scope)
      invitee = user_fixture()
      invitee_scope = Scope.for_user(invitee)
      {invitation, encoded_token} = pending_invitation_fixture(account.id, owner.id, %{email: invitee.email})
      before_call = DateTime.utc_now()

      {:ok, _member} = Invitations.accept_invitation(invitee_scope, encoded_token)

      updated = Repo.get!(Invitation, invitation.id)
      assert updated.accepted_at != nil
      assert DateTime.after?(updated.accepted_at, DateTime.add(before_call, -2, :second))
    end

    test "broadcasts :member_added event on the accounts pubsub topic" do
      {owner, scope} = user_fixture_with_scope()
      account = account_fixture(scope)
      invitee = user_fixture()
      invitee_scope = Scope.for_user(invitee)
      {_inv, encoded_token} = pending_invitation_fixture(account.id, owner.id, %{email: invitee.email})

      Phoenix.PubSub.subscribe(MetricFlow.PubSub, "accounts:user:#{invitee.id}")

      {:ok, _member} = Invitations.accept_invitation(invitee_scope, encoded_token)

      assert_receive {:member_added, %AccountMember{}}, 1000
    end

    test "returns error :not_found when token does not match any invitation" do
      {_owner, scope} = user_fixture_with_scope()
      bogus_token = Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)

      assert {:error, :not_found} = Invitations.accept_invitation(scope, bogus_token)
    end

    test "returns error :not_found when invitation has already been accepted" do
      {owner, scope} = user_fixture_with_scope()
      account = account_fixture(scope)
      invitee = user_fixture()
      invitee_scope = Scope.for_user(invitee)
      {_inv, encoded_token} = accepted_invitation_fixture(account.id, owner.id)

      assert {:error, :not_found} = Invitations.accept_invitation(invitee_scope, encoded_token)
    end

    test "returns error :not_found when invitation has already been declined" do
      {owner, scope} = user_fixture_with_scope()
      account = account_fixture(scope)
      invitee = user_fixture()
      invitee_scope = Scope.for_user(invitee)
      {invitation, encoded_token} = pending_invitation_fixture(account.id, owner.id, %{email: invitee.email})

      invitation |> Invitation.decline_changeset() |> Repo.update!()

      assert {:error, :not_found} = Invitations.accept_invitation(invitee_scope, encoded_token)
    end

    test "returns error :expired when invitation has expired" do
      {owner, scope} = user_fixture_with_scope()
      account = account_fixture(scope)
      invitee = user_fixture()
      invitee_scope = Scope.for_user(invitee)
      {_inv, encoded_token} = expired_invitation_fixture(account.id, owner.id)

      assert {:error, :expired} = Invitations.accept_invitation(invitee_scope, encoded_token)
    end

    test "returns error :already_member when the user is already a member of the account" do
      {owner, scope} = user_fixture_with_scope()
      account = account_fixture(scope)
      invitee = user_fixture()
      invitee_scope = Scope.for_user(invitee)
      insert_member!(account, invitee, :read_only)

      {_inv, encoded_token} =
        pending_invitation_fixture(account.id, owner.id, %{email: invitee.email, role: :admin})

      assert {:error, :already_member} = Invitations.accept_invitation(invitee_scope, encoded_token)
    end
  end

  # ---------------------------------------------------------------------------
  # decline_invitation/2
  # ---------------------------------------------------------------------------

  describe "decline_invitation/2" do
    test "returns ok tuple with the updated Invitation on success" do
      {owner, scope} = user_fixture_with_scope()
      account = account_fixture(scope)
      invitee = user_fixture()
      invitee_scope = Scope.for_user(invitee)
      {_inv, encoded_token} = pending_invitation_fixture(account.id, owner.id, %{email: invitee.email})

      assert {:ok, %Invitation{}} = Invitations.decline_invitation(invitee_scope, encoded_token)
    end

    test "marks the invitation status as :declined" do
      {owner, scope} = user_fixture_with_scope()
      account = account_fixture(scope)
      invitee = user_fixture()
      invitee_scope = Scope.for_user(invitee)
      {invitation, encoded_token} = pending_invitation_fixture(account.id, owner.id, %{email: invitee.email})

      {:ok, _inv} = Invitations.decline_invitation(invitee_scope, encoded_token)

      updated = Repo.get!(Invitation, invitation.id)
      assert updated.status == :declined
    end

    test "does not create an AccountMember record" do
      {owner, scope} = user_fixture_with_scope()
      account = account_fixture(scope)
      invitee = user_fixture()
      invitee_scope = Scope.for_user(invitee)
      {_inv, encoded_token} = pending_invitation_fixture(account.id, owner.id, %{email: invitee.email})

      {:ok, _inv} = Invitations.decline_invitation(invitee_scope, encoded_token)

      assert Repo.get_by(AccountMember, account_id: account.id, user_id: invitee.id) == nil
    end

    test "returns error :not_found when token does not match any invitation" do
      {_owner, scope} = user_fixture_with_scope()
      bogus_token = Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)

      assert {:error, :not_found} = Invitations.decline_invitation(scope, bogus_token)
    end

    test "returns error :not_found when invitation has already been accepted" do
      {owner, scope} = user_fixture_with_scope()
      account = account_fixture(scope)
      invitee_scope = Scope.for_user(user_fixture())
      {_inv, encoded_token} = accepted_invitation_fixture(account.id, owner.id)

      assert {:error, :not_found} = Invitations.decline_invitation(invitee_scope, encoded_token)
    end

    test "returns error :not_found when invitation has already been declined" do
      {owner, scope} = user_fixture_with_scope()
      account = account_fixture(scope)
      invitee_scope = Scope.for_user(user_fixture())
      {invitation, encoded_token} = pending_invitation_fixture(account.id, owner.id)

      invitation |> Invitation.decline_changeset() |> Repo.update!()

      assert {:error, :not_found} = Invitations.decline_invitation(invitee_scope, encoded_token)
    end

    test "returns error :expired when invitation has expired" do
      {owner, scope} = user_fixture_with_scope()
      account = account_fixture(scope)
      invitee_scope = Scope.for_user(user_fixture())
      {_inv, encoded_token} = expired_invitation_fixture(account.id, owner.id)

      assert {:error, :expired} = Invitations.decline_invitation(invitee_scope, encoded_token)
    end
  end

  # ---------------------------------------------------------------------------
  # change_invitation/2
  # ---------------------------------------------------------------------------

  describe "change_invitation/2" do
    test "returns a changeset struct" do
      {_user, scope} = user_fixture_with_scope()

      result = Invitations.change_invitation(scope, %{email: "a@example.com", role: :read_only})

      assert %Ecto.Changeset{} = result
    end

    test "changeset is invalid when recipient_email is blank" do
      {_user, scope} = user_fixture_with_scope()

      changeset = Invitations.change_invitation(scope, %{role: :read_only})

      refute changeset.valid?
      assert changeset.errors[:email] != nil
    end

    test "changeset is invalid when role is not a valid enum value" do
      {_user, scope} = user_fixture_with_scope()

      changeset = Invitations.change_invitation(scope, %{email: "a@example.com", role: :super_admin})

      refute changeset.valid?
      assert changeset.errors[:role] != nil
    end

    test "changeset is valid when all required fields are present and valid" do
      {_user, scope} = user_fixture_with_scope()

      changeset = Invitations.change_invitation(scope, %{email: "valid@example.com", role: :admin})

      assert changeset.valid?
    end
  end
end
