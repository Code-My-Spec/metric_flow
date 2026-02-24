defmodule MetricFlow.Accounts.AccountRepositoryTest do
  use MetricFlowTest.DataCase, async: true

  import MetricFlowTest.UsersFixtures

  alias MetricFlow.Accounts.Account
  alias MetricFlow.Accounts.AccountMember
  alias MetricFlow.Accounts.AccountRepository
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

  # Creates a team account with the given user as the owner.
  # This mirrors what AccountRepository.create_team_account/2 will do,
  # used here for test setup since the repository doesn't exist yet.
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

      result = AccountRepository.list_accounts(scope)

      assert result == []
    end

    test "returns personal and team accounts the user belongs to" do
      {user, scope} = user_fixture_with_scope()
      personal = personal_account_fixture(user)
      insert_member!(personal, user, :owner)
      team = account_fixture(scope)

      result = AccountRepository.list_accounts(scope)
      result_ids = Enum.map(result, & &1.id)

      assert personal.id in result_ids
      assert team.id in result_ids
    end

    test "does not return accounts the user is not a member of" do
      {_user, scope} = user_fixture_with_scope()
      other_user = user_fixture()
      other_scope = Scope.for_user(other_user)
      _other_account = account_fixture(other_scope)

      result = AccountRepository.list_accounts(scope)

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

      result = AccountRepository.get_account!(scope, account.id)

      assert result.id == account.id
    end

    test "raises when the account does not exist" do
      {_user, scope} = user_fixture_with_scope()

      assert_raise Ecto.NoResultsError, fn ->
        AccountRepository.get_account!(scope, 0)
      end
    end

    test "raises when the user is not a member of the account" do
      {_user, scope} = user_fixture_with_scope()
      other_user = user_fixture()
      other_scope = Scope.for_user(other_user)
      other_account = account_fixture(other_scope)

      assert_raise Ecto.NoResultsError, fn ->
        AccountRepository.get_account!(scope, other_account.id)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # create_team_account/2
  # ---------------------------------------------------------------------------

  describe "create_team_account/2" do
    test "creates a team account with valid attrs" do
      {_user, scope} = user_fixture_with_scope()
      attrs = %{name: "New Team", slug: unique_slug()}

      assert {:ok, account} = AccountRepository.create_team_account(scope, attrs)
      assert account.name == "New Team"
      assert account.type == "team"
    end

    test "adds the calling user as the owner member" do
      {user, scope} = user_fixture_with_scope()
      attrs = %{name: "New Team", slug: unique_slug()}

      assert {:ok, account} = AccountRepository.create_team_account(scope, attrs)

      member = Repo.get_by(AccountMember, account_id: account.id, user_id: user.id)
      assert member.role == :owner
    end

    test "requires name to be set" do
      {_user, scope} = user_fixture_with_scope()
      attrs = %{name: nil, slug: unique_slug()}

      assert {:error, changeset} = AccountRepository.create_team_account(scope, attrs)
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires slug to be set and unique" do
      {_user, scope} = user_fixture_with_scope()
      existing = account_fixture(scope)

      attrs = %{name: "Another Team", slug: existing.slug}

      assert {:error, changeset} = AccountRepository.create_team_account(scope, attrs)
      assert %{slug: ["has already been taken"]} = errors_on(changeset)
    end

    test "validates slug format (lowercase letters, numbers, hyphens)" do
      {_user, scope} = user_fixture_with_scope()
      attrs = %{name: "New Team", slug: "Invalid Slug!"}

      assert {:error, changeset} = AccountRepository.create_team_account(scope, attrs)
      assert %{slug: [_format_error]} = errors_on(changeset)
    end

    test "does not create account when attrs are invalid" do
      {_user, scope} = user_fixture_with_scope()
      attrs = %{name: nil, slug: nil}

      assert {:error, changeset} = AccountRepository.create_team_account(scope, attrs)
      refute changeset.valid?
    end

    test "broadcasts {:created, account} on success" do
      {user, scope} = user_fixture_with_scope()
      Phoenix.PubSub.subscribe(MetricFlow.PubSub, "accounts:user:#{user.id}")
      attrs = %{name: "New Team", slug: unique_slug()}

      assert {:ok, account} = AccountRepository.create_team_account(scope, attrs)

      assert_receive {:created, ^account}
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

      assert {:ok, updated} = AccountRepository.update_account(scope, account, attrs)
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

      assert {:ok, updated} = AccountRepository.update_account(admin_scope, account, attrs)
      assert updated.name == "Admin Updated"
    end

    test "returns {:error, :unauthorized} for account_manager role" do
      {owner_user, _owner_scope} = user_fixture_with_scope()
      owner_scope = Scope.for_user(owner_user)
      account = account_fixture(owner_scope)

      manager_user = user_fixture()
      insert_member!(account, manager_user, :account_manager)
      manager_scope = Scope.for_user(manager_user)

      assert {:error, :unauthorized} =
               AccountRepository.update_account(manager_scope, account, %{name: "Attempt"})
    end

    test "returns {:error, :unauthorized} for read_only role" do
      {owner_user, _owner_scope} = user_fixture_with_scope()
      owner_scope = Scope.for_user(owner_user)
      account = account_fixture(owner_scope)

      reader_user = user_fixture()
      insert_member!(account, reader_user, :read_only)
      reader_scope = Scope.for_user(reader_user)

      assert {:error, :unauthorized} =
               AccountRepository.update_account(reader_scope, account, %{name: "Attempt"})
    end

    test "returns changeset error for invalid slug format" do
      {_user, scope} = user_fixture_with_scope()
      account = account_fixture(scope)

      assert {:error, changeset} =
               AccountRepository.update_account(scope, account, %{
                 name: "Valid Name",
                 slug: "Bad Slug!"
               })

      assert %{slug: [_format_error]} = errors_on(changeset)
    end

    test "returns changeset error for duplicate slug" do
      {_user, scope} = user_fixture_with_scope()
      account = account_fixture(scope)
      other_account = account_fixture(scope)

      assert {:error, changeset} =
               AccountRepository.update_account(scope, account, %{
                 name: "Valid Name",
                 slug: other_account.slug
               })

      assert %{slug: ["has already been taken"]} = errors_on(changeset)
    end

    test "broadcasts {:updated, account} on success" do
      {user, scope} = user_fixture_with_scope()
      account = account_fixture(scope)
      Phoenix.PubSub.subscribe(MetricFlow.PubSub, "accounts:user:#{user.id}")
      attrs = %{name: "Broadcast Update", slug: unique_slug()}

      assert {:ok, updated} = AccountRepository.update_account(scope, account, attrs)

      assert_receive {:updated, ^updated}
    end
  end

  # ---------------------------------------------------------------------------
  # delete_account/2
  # ---------------------------------------------------------------------------

  describe "delete_account/2" do
    test "deletes the account when called by the owner" do
      {_user, scope} = user_fixture_with_scope()
      account = account_fixture(scope)

      assert {:ok, deleted} = AccountRepository.delete_account(scope, account)
      assert deleted.id == account.id
      assert Repo.get(Account, account.id) == nil
    end

    test "returns {:error, :unauthorized} for admin role" do
      {owner_user, _owner_scope} = user_fixture_with_scope()
      owner_scope = Scope.for_user(owner_user)
      account = account_fixture(owner_scope)

      admin_user = user_fixture()
      insert_member!(account, admin_user, :admin)
      admin_scope = Scope.for_user(admin_user)

      assert {:error, :unauthorized} = AccountRepository.delete_account(admin_scope, account)
    end

    test "returns {:error, :unauthorized} for account_manager role" do
      {owner_user, _owner_scope} = user_fixture_with_scope()
      owner_scope = Scope.for_user(owner_user)
      account = account_fixture(owner_scope)

      manager_user = user_fixture()
      insert_member!(account, manager_user, :account_manager)
      manager_scope = Scope.for_user(manager_user)

      assert {:error, :unauthorized} = AccountRepository.delete_account(manager_scope, account)
    end

    test "returns {:error, :personal_account} for personal accounts" do
      {user, scope} = user_fixture_with_scope()
      personal = personal_account_fixture(user)

      assert {:error, :personal_account} = AccountRepository.delete_account(scope, personal)
    end

    test "removes all account members on deletion" do
      {_user, scope} = user_fixture_with_scope()
      account = account_fixture(scope)
      extra_user = user_fixture()
      insert_member!(account, extra_user, :admin)

      assert {:ok, _deleted} = AccountRepository.delete_account(scope, account)

      remaining = Repo.all(from m in AccountMember, where: m.account_id == ^account.id)
      assert remaining == []
    end

    test "broadcasts {:deleted, account} on success" do
      {user, scope} = user_fixture_with_scope()
      account = account_fixture(scope)
      Phoenix.PubSub.subscribe(MetricFlow.PubSub, "accounts:user:#{user.id}")

      assert {:ok, deleted} = AccountRepository.delete_account(scope, account)

      assert_receive {:deleted, ^deleted}
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

      members = AccountRepository.list_account_members(scope, account.id)

      assert length(members) == 2
      assert Enum.all?(members, &Ecto.assoc_loaded?(&1.user))
    end

    test "returns at least the calling user when they are the only member" do
      {user, scope} = user_fixture_with_scope()
      account = account_fixture(scope)

      members = AccountRepository.list_account_members(scope, account.id)

      assert length(members) == 1
      assert hd(members).user_id == user.id
    end

    test "raises when the calling user is not a member of the account" do
      {_owner, owner_scope} = user_fixture_with_scope()
      account = account_fixture(owner_scope)

      {_other, other_scope} = user_fixture_with_scope()

      assert_raise Ecto.NoResultsError, fn ->
        AccountRepository.list_account_members(other_scope, account.id)
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

      result = AccountRepository.get_user_role(scope, owner.id, account.id)

      assert result == :owner
    end

    test "returns nil when the user is not a member of the account" do
      {_owner, scope} = user_fixture_with_scope()
      account = account_fixture(scope)
      non_member = user_fixture()

      result = AccountRepository.get_user_role(scope, non_member.id, account.id)

      assert result == nil
    end

    test "returns nil for a non-existent user_id" do
      {_owner, scope} = user_fixture_with_scope()
      account = account_fixture(scope)

      result = AccountRepository.get_user_role(scope, 0, account.id)

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

      assert {:ok, member} =
               AccountRepository.update_user_role(scope, target_user.id, account.id, :admin)

      assert member.role == :admin
      assert member.user_id == target_user.id
    end

    test "allows an owner to promote a member to owner" do
      {_owner, scope} = user_fixture_with_scope()
      account = account_fixture(scope)
      target_user = user_fixture()
      insert_member!(account, target_user, :read_only)

      assert {:ok, member} =
               AccountRepository.update_user_role(scope, target_user.id, account.id, :owner)

      assert member.role == :owner
    end

    test "allows an owner to promote a member to admin" do
      {_owner, scope} = user_fixture_with_scope()
      account = account_fixture(scope)
      target_user = user_fixture()
      insert_member!(account, target_user, :read_only)

      assert {:ok, member} =
               AccountRepository.update_user_role(scope, target_user.id, account.id, :admin)

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
               AccountRepository.update_user_role(
                 admin_scope,
                 target_user.id,
                 account.id,
                 :account_manager
               )

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
               AccountRepository.update_user_role(
                 admin_scope,
                 target_user.id,
                 account.id,
                 :owner
               )
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
               AccountRepository.update_user_role(
                 admin_scope,
                 target_user.id,
                 account.id,
                 :admin
               )
    end

    test "returns {:error, :last_owner} when demoting the sole owner" do
      {owner, scope} = user_fixture_with_scope()
      account = account_fixture(scope)

      assert {:error, :last_owner} =
               AccountRepository.update_user_role(scope, owner.id, account.id, :admin)
    end

    test "returns {:error, :unauthorized} for account_manager and read_only roles" do
      {owner, _owner_scope} = user_fixture_with_scope()
      owner_scope = Scope.for_user(owner)
      account = account_fixture(owner_scope)

      manager_user = user_fixture()
      insert_member!(account, manager_user, :account_manager)
      manager_scope = Scope.for_user(manager_user)

      target_user = user_fixture()
      insert_member!(account, target_user, :read_only)

      assert {:error, :unauthorized} =
               AccountRepository.update_user_role(
                 manager_scope,
                 target_user.id,
                 account.id,
                 :read_only
               )
    end

    test "broadcasts {:updated, account_member} on success" do
      {_owner, scope} = user_fixture_with_scope()
      account = account_fixture(scope)
      target_user = user_fixture()
      insert_member!(account, target_user, :read_only)

      Phoenix.PubSub.subscribe(MetricFlow.PubSub, "account_members:user:#{target_user.id}")

      assert {:ok, member} =
               AccountRepository.update_user_role(scope, target_user.id, account.id, :admin)

      assert_receive {:updated, ^member}
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

      assert {:ok, _member} =
               AccountRepository.remove_user_from_account(scope, target_user.id, account.id)

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
               AccountRepository.remove_user_from_account(admin_scope, target_user.id, account.id)

      assert Repo.get_by(AccountMember, account_id: account.id, user_id: target_user.id) == nil
    end

    test "returns {:error, :last_owner} when removing the sole owner" do
      {owner, scope} = user_fixture_with_scope()
      account = account_fixture(scope)

      assert {:error, :last_owner} =
               AccountRepository.remove_user_from_account(scope, owner.id, account.id)
    end

    test "returns {:error, :unauthorized} for account_manager and read_only roles" do
      {owner, _owner_scope} = user_fixture_with_scope()
      owner_scope = Scope.for_user(owner)
      account = account_fixture(owner_scope)

      manager_user = user_fixture()
      insert_member!(account, manager_user, :account_manager)
      manager_scope = Scope.for_user(manager_user)

      target_user = user_fixture()
      insert_member!(account, target_user, :read_only)

      assert {:error, :unauthorized} =
               AccountRepository.remove_user_from_account(
                 manager_scope,
                 target_user.id,
                 account.id
               )
    end

    test "broadcasts {:deleted, account_member} on success" do
      {_owner, scope} = user_fixture_with_scope()
      account = account_fixture(scope)
      target_user = user_fixture()
      insert_member!(account, target_user, :read_only)

      Phoenix.PubSub.subscribe(MetricFlow.PubSub, "account_members:user:#{target_user.id}")

      assert {:ok, member} =
               AccountRepository.remove_user_from_account(scope, target_user.id, account.id)

      assert_receive {:deleted, ^member}
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

      assert {:ok, member} =
               AccountRepository.add_user_to_account(scope, new_user.id, account.id, :read_only)

      assert member.user_id == new_user.id
      assert member.account_id == account.id
      assert member.role == :read_only
    end

    test "returns {:error, :already_member} when the user is already a member" do
      {owner, scope} = user_fixture_with_scope()
      account = account_fixture(scope)

      assert {:error, :already_member} =
               AccountRepository.add_user_to_account(scope, owner.id, account.id, :read_only)
    end

    test "allows owner to add a member with owner role" do
      {_owner, scope} = user_fixture_with_scope()
      account = account_fixture(scope)
      new_user = user_fixture()

      assert {:ok, member} =
               AccountRepository.add_user_to_account(scope, new_user.id, account.id, :owner)

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
               AccountRepository.add_user_to_account(admin_scope, new_user.id, account.id, :owner)
    end

    test "returns {:error, :unauthorized} for account_manager and read_only roles" do
      {owner, _owner_scope} = user_fixture_with_scope()
      owner_scope = Scope.for_user(owner)
      account = account_fixture(owner_scope)

      manager_user = user_fixture()
      insert_member!(account, manager_user, :account_manager)
      manager_scope = Scope.for_user(manager_user)

      new_user = user_fixture()

      assert {:error, :unauthorized} =
               AccountRepository.add_user_to_account(
                 manager_scope,
                 new_user.id,
                 account.id,
                 :read_only
               )
    end

    test "broadcasts {:created, account_member} on success" do
      {_owner, scope} = user_fixture_with_scope()
      account = account_fixture(scope)
      new_user = user_fixture()

      Phoenix.PubSub.subscribe(MetricFlow.PubSub, "account_members:user:#{new_user.id}")

      assert {:ok, member} =
               AccountRepository.add_user_to_account(scope, new_user.id, account.id, :read_only)

      assert_receive {:created, ^member}
    end
  end
end
