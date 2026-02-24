defmodule MetricFlow.AccountsTest do
  use MetricFlowTest.DataCase, async: true

  import MetricFlowTest.UsersFixtures

  alias MetricFlow.Accounts
  alias MetricFlow.Accounts.Account
  alias MetricFlow.Accounts.AccountMember
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

  defp insert_account!(user, attrs) do
    defaults = %{
      name: "Test Account",
      slug: unique_slug(),
      type: "team",
      originator_user_id: user.id
    }

    %Account{}
    |> Account.creation_changeset(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end

  defp insert_member!(account, user, role) do
    %AccountMember{}
    |> AccountMember.changeset(%{
      account_id: account.id,
      user_id: user.id,
      role: role
    })
    |> Repo.insert!()
  end

  # Creates a team account with the given user as owner.
  defp account_fixture(scope, attrs \\ %{}) do
    user = scope.user
    account = insert_account!(user, Map.merge(%{type: "team"}, attrs))
    insert_member!(account, user, :owner)
    account
  end

  defp personal_account_fixture(user) do
    %Account{}
    |> Account.creation_changeset(%{
      name: "Personal Account",
      slug: unique_slug(),
      type: "personal",
      originator_user_id: user.id
    })
    |> Repo.insert!()
  end

  # ---------------------------------------------------------------------------
  # list_accounts/1
  # ---------------------------------------------------------------------------

  describe "list_accounts/1" do
    test "returns an empty list when the user has no accounts" do
      {_user, scope} = user_fixture_with_scope()

      result = Accounts.list_accounts(scope)

      assert result == []
    end

    test "returns personal and team accounts the user belongs to" do
      {user, scope} = user_fixture_with_scope()
      personal = personal_account_fixture(user)
      insert_member!(personal, user, :owner)
      team = account_fixture(scope)

      result = Accounts.list_accounts(scope)
      result_ids = Enum.map(result, & &1.id)

      assert personal.id in result_ids
      assert team.id in result_ids
    end

    test "does not return accounts the user is not a member of" do
      {_user, scope} = user_fixture_with_scope()
      other_user = user_fixture()
      other_scope = Scope.for_user(other_user)
      _other_account = account_fixture(other_scope)

      result = Accounts.list_accounts(scope)

      assert result == []
    end
  end

  # ---------------------------------------------------------------------------
  # get_account!/2
  # ---------------------------------------------------------------------------

  describe "get_account!/2" do
    test "returns the account when the user is a member" do
      {_user, scope} = user_fixture_with_scope()
      account = account_fixture(scope)

      result = Accounts.get_account!(scope, account.id)

      assert result.id == account.id
    end

    test "raises when the account does not exist" do
      {_user, scope} = user_fixture_with_scope()

      assert_raise Ecto.NoResultsError, fn ->
        Accounts.get_account!(scope, 0)
      end
    end

    test "raises when the user is not a member of the account" do
      {_user, scope} = user_fixture_with_scope()
      other_user = user_fixture()
      other_scope = Scope.for_user(other_user)
      other_account = account_fixture(other_scope)

      assert_raise Ecto.NoResultsError, fn ->
        Accounts.get_account!(scope, other_account.id)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # change_account/2
  # ---------------------------------------------------------------------------

  describe "change_account/2" do
    test "returns a valid changeset for an existing account" do
      {_user, scope} = user_fixture_with_scope()
      account = account_fixture(scope)

      changeset = Accounts.change_account(scope, account)

      assert %Ecto.Changeset{} = changeset
      assert changeset.data.id == account.id
    end

    test "returns a changeset with no errors when attrs are empty" do
      {_user, scope} = user_fixture_with_scope()
      account = account_fixture(scope)

      changeset = Accounts.change_account(scope, account)

      assert changeset.errors == []
    end
  end

  # ---------------------------------------------------------------------------
  # change_account/3
  # ---------------------------------------------------------------------------

  describe "change_account/3" do
    test "returns a changeset with validation errors for invalid attrs" do
      {_user, scope} = user_fixture_with_scope()
      account = account_fixture(scope)

      changeset = Accounts.change_account(scope, account, %{name: nil, slug: "Bad Slug!"})

      refute changeset.valid?
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "returns a valid changeset for valid attrs" do
      {_user, scope} = user_fixture_with_scope()
      account = account_fixture(scope)
      attrs = %{name: "Updated Name", slug: unique_slug()}

      changeset = Accounts.change_account(scope, account, attrs)

      assert changeset.valid?
    end
  end

  # ---------------------------------------------------------------------------
  # create_team_account/2
  # ---------------------------------------------------------------------------

  describe "create_team_account/2" do
    test "creates a team account with valid attrs" do
      {_user, scope} = user_fixture_with_scope()
      attrs = %{name: "New Team", slug: unique_slug()}

      assert {:ok, account} = Accounts.create_team_account(scope, attrs)
      assert account.name == "New Team"
      assert account.type == "team"
    end

    test "adds the calling user as the owner" do
      {user, scope} = user_fixture_with_scope()
      attrs = %{name: "New Team", slug: unique_slug()}

      assert {:ok, account} = Accounts.create_team_account(scope, attrs)

      member = Repo.get_by(AccountMember, account_id: account.id, user_id: user.id)
      assert member.role == :owner
    end

    test "requires name to be set" do
      {_user, scope} = user_fixture_with_scope()
      attrs = %{name: nil, slug: unique_slug()}

      assert {:error, changeset} = Accounts.create_team_account(scope, attrs)
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires slug to be set and unique" do
      {_user, scope} = user_fixture_with_scope()
      existing = account_fixture(scope)
      attrs = %{name: "Another Team", slug: existing.slug}

      assert {:error, changeset} = Accounts.create_team_account(scope, attrs)
      assert %{slug: ["has already been taken"]} = errors_on(changeset)
    end

    test "validates slug format (lowercase letters, numbers, hyphens)" do
      {_user, scope} = user_fixture_with_scope()
      attrs = %{name: "New Team", slug: "Invalid Slug!"}

      assert {:error, changeset} = Accounts.create_team_account(scope, attrs)
      assert %{slug: [_format_error]} = errors_on(changeset)
    end

    test "does not create account when attrs are invalid" do
      {_user, scope} = user_fixture_with_scope()
      attrs = %{name: nil, slug: nil}

      assert {:error, changeset} = Accounts.create_team_account(scope, attrs)
      refute changeset.valid?
    end
  end

  # ---------------------------------------------------------------------------
  # update_account/3
  # ---------------------------------------------------------------------------

  describe "update_account/3" do
    test "updates the account name and slug for an owner" do
      {_user, scope} = user_fixture_with_scope()
      account = account_fixture(scope)
      new_slug = unique_slug()
      attrs = %{name: "Updated Name", slug: new_slug}

      assert {:ok, updated} = Accounts.update_account(scope, account, attrs)
      assert updated.name == "Updated Name"
      assert updated.slug == new_slug
    end

    test "updates the account name and slug for an admin" do
      {owner_user, _owner_scope} = user_fixture_with_scope()
      owner_scope = Scope.for_user(owner_user)
      account = account_fixture(owner_scope)

      admin_user = user_fixture()
      insert_member!(account, admin_user, :admin)
      admin_scope = Scope.for_user(admin_user)

      attrs = %{name: "Admin Updated", slug: unique_slug()}

      assert {:ok, updated} = Accounts.update_account(admin_scope, account, attrs)
      assert updated.name == "Admin Updated"
    end

    test "returns unauthorized for account_manager role" do
      {owner_user, _owner_scope} = user_fixture_with_scope()
      owner_scope = Scope.for_user(owner_user)
      account = account_fixture(owner_scope)

      manager_user = user_fixture()
      insert_member!(account, manager_user, :account_manager)
      manager_scope = Scope.for_user(manager_user)

      assert {:error, :unauthorized} =
               Accounts.update_account(manager_scope, account, %{name: "Attempt"})
    end

    test "returns unauthorized for read_only role" do
      {owner_user, _owner_scope} = user_fixture_with_scope()
      owner_scope = Scope.for_user(owner_user)
      account = account_fixture(owner_scope)

      reader_user = user_fixture()
      insert_member!(account, reader_user, :read_only)
      reader_scope = Scope.for_user(reader_user)

      assert {:error, :unauthorized} =
               Accounts.update_account(reader_scope, account, %{name: "Attempt"})
    end

    test "returns changeset error for invalid slug format" do
      {_user, scope} = user_fixture_with_scope()
      account = account_fixture(scope)

      assert {:error, changeset} =
               Accounts.update_account(scope, account, %{name: "Valid Name", slug: "Bad Slug!"})

      assert %{slug: [_format_error]} = errors_on(changeset)
    end

    test "returns changeset error for duplicate slug" do
      {_user, scope} = user_fixture_with_scope()
      account = account_fixture(scope)
      other_account = account_fixture(scope)

      assert {:error, changeset} =
               Accounts.update_account(scope, account, %{
                 name: "Valid Name",
                 slug: other_account.slug
               })

      assert %{slug: ["has already been taken"]} = errors_on(changeset)
    end
  end

  # ---------------------------------------------------------------------------
  # delete_account/2
  # ---------------------------------------------------------------------------

  describe "delete_account/2" do
    test "deletes the account when called by the owner" do
      {_user, scope} = user_fixture_with_scope()
      account = account_fixture(scope)

      assert {:ok, deleted} = Accounts.delete_account(scope, account)
      assert deleted.id == account.id
      assert Repo.get(Account, account.id) == nil
    end

    test "returns unauthorized for admin role" do
      {owner_user, _owner_scope} = user_fixture_with_scope()
      owner_scope = Scope.for_user(owner_user)
      account = account_fixture(owner_scope)

      admin_user = user_fixture()
      insert_member!(account, admin_user, :admin)
      admin_scope = Scope.for_user(admin_user)

      assert {:error, :unauthorized} = Accounts.delete_account(admin_scope, account)
    end

    test "returns unauthorized for account_manager role" do
      {owner_user, _owner_scope} = user_fixture_with_scope()
      owner_scope = Scope.for_user(owner_user)
      account = account_fixture(owner_scope)

      manager_user = user_fixture()
      insert_member!(account, manager_user, :account_manager)
      manager_scope = Scope.for_user(manager_user)

      assert {:error, :unauthorized} = Accounts.delete_account(manager_scope, account)
    end

    test "returns personal_account error for personal accounts" do
      {user, scope} = user_fixture_with_scope()
      personal = personal_account_fixture(user)

      assert {:error, :personal_account} = Accounts.delete_account(scope, personal)
    end

    test "removes all account members on deletion" do
      {_user, scope} = user_fixture_with_scope()
      account = account_fixture(scope)
      extra_user = user_fixture()
      insert_member!(account, extra_user, :admin)

      assert {:ok, _deleted} = Accounts.delete_account(scope, account)

      remaining = Repo.all(from m in AccountMember, where: m.account_id == ^account.id)
      assert remaining == []
    end
  end

  # ---------------------------------------------------------------------------
  # list_account_members/2
  # ---------------------------------------------------------------------------

  describe "list_account_members/2" do
    test "returns all members with preloaded user data" do
      {_owner, scope} = user_fixture_with_scope()
      account = account_fixture(scope)
      extra_user = user_fixture()
      insert_member!(account, extra_user, :admin)

      members = Accounts.list_account_members(scope, account.id)

      assert length(members) == 2
      assert Enum.all?(members, &Ecto.assoc_loaded?(&1.user))
    end

    test "returns at least the calling user when they are the only member" do
      {user, scope} = user_fixture_with_scope()
      account = account_fixture(scope)

      members = Accounts.list_account_members(scope, account.id)

      assert length(members) == 1
      assert hd(members).user_id == user.id
    end

    test "raises when the calling user is not a member of the account" do
      {_owner, owner_scope} = user_fixture_with_scope()
      account = account_fixture(owner_scope)

      {_other, other_scope} = user_fixture_with_scope()

      assert_raise Ecto.NoResultsError, fn ->
        Accounts.list_account_members(other_scope, account.id)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # get_user_role/3
  # ---------------------------------------------------------------------------

  describe "get_user_role/3" do
    test "returns the correct role for a member" do
      {owner, scope} = user_fixture_with_scope()
      account = account_fixture(scope)

      result = Accounts.get_user_role(scope, owner.id, account.id)

      assert result == :owner
    end

    test "returns nil when the user is not a member of the account" do
      {_owner, scope} = user_fixture_with_scope()
      account = account_fixture(scope)
      non_member = user_fixture()

      result = Accounts.get_user_role(scope, non_member.id, account.id)

      assert result == nil
    end

    test "returns nil for a non-existent user_id" do
      {_owner, scope} = user_fixture_with_scope()
      account = account_fixture(scope)

      result = Accounts.get_user_role(scope, 0, account.id)

      assert result == nil
    end
  end

  # ---------------------------------------------------------------------------
  # update_user_role/4
  # ---------------------------------------------------------------------------

  describe "update_user_role/4" do
    test "updates the role for a valid target user" do
      {_owner, scope} = user_fixture_with_scope()
      account = account_fixture(scope)
      target_user = user_fixture()
      insert_member!(account, target_user, :read_only)

      assert {:ok, member} = Accounts.update_user_role(scope, target_user.id, account.id, :admin)

      assert member.role == :admin
      assert member.user_id == target_user.id
    end

    test "allows an owner to promote a member to owner" do
      {_owner, scope} = user_fixture_with_scope()
      account = account_fixture(scope)
      target_user = user_fixture()
      insert_member!(account, target_user, :read_only)

      assert {:ok, member} = Accounts.update_user_role(scope, target_user.id, account.id, :owner)

      assert member.role == :owner
    end

    test "allows an owner to promote a member to admin" do
      {_owner, scope} = user_fixture_with_scope()
      account = account_fixture(scope)
      target_user = user_fixture()
      insert_member!(account, target_user, :read_only)

      assert {:ok, member} = Accounts.update_user_role(scope, target_user.id, account.id, :admin)

      assert member.role == :admin
    end

    test "allows an admin to promote a member to account_manager or read_only" do
      {owner, _owner_scope} = user_fixture_with_scope()
      owner_scope = Scope.for_user(owner)
      account = account_fixture(owner_scope)

      admin_user = user_fixture()
      insert_member!(account, admin_user, :admin)
      admin_scope = Scope.for_user(admin_user)

      target_user = user_fixture()
      insert_member!(account, target_user, :read_only)

      assert {:ok, member} =
               Accounts.update_user_role(admin_scope, target_user.id, account.id, :account_manager)

      assert member.role == :account_manager
    end

    test "prevents an admin from promoting a member to owner" do
      {owner, _owner_scope} = user_fixture_with_scope()
      owner_scope = Scope.for_user(owner)
      account = account_fixture(owner_scope)

      admin_user = user_fixture()
      insert_member!(account, admin_user, :admin)
      admin_scope = Scope.for_user(admin_user)

      target_user = user_fixture()
      insert_member!(account, target_user, :read_only)

      assert {:error, :unauthorized} =
               Accounts.update_user_role(admin_scope, target_user.id, account.id, :owner)
    end

    test "prevents an admin from promoting a member to admin" do
      {owner, _owner_scope} = user_fixture_with_scope()
      owner_scope = Scope.for_user(owner)
      account = account_fixture(owner_scope)

      admin_user = user_fixture()
      insert_member!(account, admin_user, :admin)
      admin_scope = Scope.for_user(admin_user)

      target_user = user_fixture()
      insert_member!(account, target_user, :read_only)

      assert {:error, :unauthorized} =
               Accounts.update_user_role(admin_scope, target_user.id, account.id, :admin)
    end

    test "returns last_owner error when demoting the sole owner" do
      {owner, scope} = user_fixture_with_scope()
      account = account_fixture(scope)

      assert {:error, :last_owner} =
               Accounts.update_user_role(scope, owner.id, account.id, :admin)
    end

    test "returns unauthorized for account_manager and read_only roles" do
      {owner, _owner_scope} = user_fixture_with_scope()
      owner_scope = Scope.for_user(owner)
      account = account_fixture(owner_scope)

      manager_user = user_fixture()
      insert_member!(account, manager_user, :account_manager)
      manager_scope = Scope.for_user(manager_user)

      target_user = user_fixture()
      insert_member!(account, target_user, :read_only)

      assert {:error, :unauthorized} =
               Accounts.update_user_role(manager_scope, target_user.id, account.id, :read_only)
    end
  end

  # ---------------------------------------------------------------------------
  # remove_user_from_account/3
  # ---------------------------------------------------------------------------

  describe "remove_user_from_account/3" do
    test "removes a member when called by the owner" do
      {_owner, scope} = user_fixture_with_scope()
      account = account_fixture(scope)
      target_user = user_fixture()
      insert_member!(account, target_user, :read_only)

      assert {:ok, _member} = Accounts.remove_user_from_account(scope, target_user.id, account.id)

      assert Repo.get_by(AccountMember, account_id: account.id, user_id: target_user.id) == nil
    end

    test "removes a member when called by an admin" do
      {owner, _owner_scope} = user_fixture_with_scope()
      owner_scope = Scope.for_user(owner)
      account = account_fixture(owner_scope)

      admin_user = user_fixture()
      insert_member!(account, admin_user, :admin)
      admin_scope = Scope.for_user(admin_user)

      target_user = user_fixture()
      insert_member!(account, target_user, :read_only)

      assert {:ok, _member} =
               Accounts.remove_user_from_account(admin_scope, target_user.id, account.id)

      assert Repo.get_by(AccountMember, account_id: account.id, user_id: target_user.id) == nil
    end

    test "returns last_owner error when removing the sole owner" do
      {owner, scope} = user_fixture_with_scope()
      account = account_fixture(scope)

      assert {:error, :last_owner} =
               Accounts.remove_user_from_account(scope, owner.id, account.id)
    end

    test "returns unauthorized for account_manager and read_only roles" do
      {owner, _owner_scope} = user_fixture_with_scope()
      owner_scope = Scope.for_user(owner)
      account = account_fixture(owner_scope)

      manager_user = user_fixture()
      insert_member!(account, manager_user, :account_manager)
      manager_scope = Scope.for_user(manager_user)

      target_user = user_fixture()
      insert_member!(account, target_user, :read_only)

      assert {:error, :unauthorized} =
               Accounts.remove_user_from_account(manager_scope, target_user.id, account.id)
    end
  end

  # ---------------------------------------------------------------------------
  # add_user_to_account/4
  # ---------------------------------------------------------------------------

  describe "add_user_to_account/4" do
    test "adds a member with the given role" do
      {_owner, scope} = user_fixture_with_scope()
      account = account_fixture(scope)
      new_user = user_fixture()

      assert {:ok, member} = Accounts.add_user_to_account(scope, new_user.id, account.id, :read_only)

      assert member.user_id == new_user.id
      assert member.account_id == account.id
      assert member.role == :read_only
    end

    test "returns already_member error when user is already a member" do
      {owner, scope} = user_fixture_with_scope()
      account = account_fixture(scope)

      assert {:error, :already_member} =
               Accounts.add_user_to_account(scope, owner.id, account.id, :read_only)
    end

    test "allows owner to add a member with owner role" do
      {_owner, scope} = user_fixture_with_scope()
      account = account_fixture(scope)
      new_user = user_fixture()

      assert {:ok, member} = Accounts.add_user_to_account(scope, new_user.id, account.id, :owner)

      assert member.role == :owner
    end

    test "prevents admin from adding a member with owner role" do
      {owner, _owner_scope} = user_fixture_with_scope()
      owner_scope = Scope.for_user(owner)
      account = account_fixture(owner_scope)

      admin_user = user_fixture()
      insert_member!(account, admin_user, :admin)
      admin_scope = Scope.for_user(admin_user)

      new_user = user_fixture()

      assert {:error, :unauthorized} =
               Accounts.add_user_to_account(admin_scope, new_user.id, account.id, :owner)
    end

    test "returns unauthorized for account_manager and read_only roles" do
      {owner, _owner_scope} = user_fixture_with_scope()
      owner_scope = Scope.for_user(owner)
      account = account_fixture(owner_scope)

      manager_user = user_fixture()
      insert_member!(account, manager_user, :account_manager)
      manager_scope = Scope.for_user(manager_user)

      new_user = user_fixture()

      assert {:error, :unauthorized} =
               Accounts.add_user_to_account(manager_scope, new_user.id, account.id, :read_only)
    end
  end

  # ---------------------------------------------------------------------------
  # subscribe_account/1
  # ---------------------------------------------------------------------------

  describe "subscribe_account/1" do
    test "subscribes to the account topic" do
      {user, scope} = user_fixture_with_scope()

      assert :ok = Accounts.subscribe_account(scope)

      Phoenix.PubSub.broadcast(MetricFlow.PubSub, "accounts:user:#{user.id}", :test_message)
      assert_receive :test_message
    end

    test "receives {:created, account} message after create_team_account" do
      {_user, scope} = user_fixture_with_scope()
      Accounts.subscribe_account(scope)

      attrs = %{name: "New Team", slug: unique_slug()}
      assert {:ok, account} = Accounts.create_team_account(scope, attrs)

      assert_receive {:created, ^account}
    end

    test "receives {:updated, account} message after update_account" do
      {_user, scope} = user_fixture_with_scope()
      account = account_fixture(scope)
      Accounts.subscribe_account(scope)

      attrs = %{name: "Updated Name", slug: unique_slug()}
      assert {:ok, updated} = Accounts.update_account(scope, account, attrs)

      assert_receive {:updated, ^updated}
    end

    test "receives {:deleted, account} message after delete_account" do
      {_user, scope} = user_fixture_with_scope()
      account = account_fixture(scope)
      Accounts.subscribe_account(scope)

      assert {:ok, deleted} = Accounts.delete_account(scope, account)

      assert_receive {:deleted, ^deleted}
    end
  end

  # ---------------------------------------------------------------------------
  # subscribe_member/1
  # ---------------------------------------------------------------------------

  describe "subscribe_member/1" do
    test "subscribes to the member topic" do
      {user, scope} = user_fixture_with_scope()

      assert :ok = Accounts.subscribe_member(scope)

      Phoenix.PubSub.broadcast(
        MetricFlow.PubSub,
        "account_members:user:#{user.id}",
        :test_message
      )

      assert_receive :test_message
    end

    test "receives {:created, account_member} message after add_user_to_account" do
      {_owner, scope} = user_fixture_with_scope()
      account = account_fixture(scope)
      new_user = user_fixture()
      new_user_scope = Scope.for_user(new_user)
      Accounts.subscribe_member(new_user_scope)

      assert {:ok, member} = Accounts.add_user_to_account(scope, new_user.id, account.id, :read_only)

      assert_receive {:created, ^member}
    end

    test "receives {:updated, account_member} message after update_user_role" do
      {_owner, scope} = user_fixture_with_scope()
      account = account_fixture(scope)
      target_user = user_fixture()
      insert_member!(account, target_user, :read_only)
      target_scope = Scope.for_user(target_user)
      Accounts.subscribe_member(target_scope)

      assert {:ok, member} = Accounts.update_user_role(scope, target_user.id, account.id, :admin)

      assert_receive {:updated, ^member}
    end

    test "receives {:deleted, account_member} message after remove_user_from_account" do
      {_owner, scope} = user_fixture_with_scope()
      account = account_fixture(scope)
      target_user = user_fixture()
      insert_member!(account, target_user, :read_only)
      target_scope = Scope.for_user(target_user)
      Accounts.subscribe_member(target_scope)

      assert {:ok, member} = Accounts.remove_user_from_account(scope, target_user.id, account.id)

      assert_receive {:deleted, ^member}
    end
  end
end
