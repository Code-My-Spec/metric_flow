defmodule MetricFlow.Accounts.MembersRepositoryTest do
  use MetricFlow.DataCase, async: true

  import MetricFlow.{AccountsFixtures, UsersFixtures}

  alias MetricFlow.Accounts.{Member, MembersRepository}

  describe "add_user_to_account/3" do
    test "adds user to account with default member role" do
      user = user_fixture()
      account = account_fixture()

      assert {:ok, %Member{} = member} =
               MembersRepository.add_user_to_account(user.id, account.id)

      assert member.user_id == user.id
      assert member.account_id == account.id
      assert member.role == :member
    end

    test "adds user to account with specified role" do
      user = user_fixture()
      account = account_fixture()

      assert {:ok, %Member{} = member} =
               MembersRepository.add_user_to_account(user.id, account.id, :admin)

      assert member.role == :admin
    end

    test "returns error when user is already member of account" do
      user = user_fixture()
      account = account_fixture()
      member_fixture(user, account)

      assert {:error, changeset} = MembersRepository.add_user_to_account(user.id, account.id)
      assert "has already been taken" in errors_on(changeset).user_id
    end

    test "returns error when user does not exist" do
      account = account_fixture()

      assert {:error, changeset} = MembersRepository.add_user_to_account(999, account.id)
      assert "does not exist" in errors_on(changeset).user
    end

    test "returns error when account does not exist" do
      user = user_fixture()

      assert {:error, changeset} =
               MembersRepository.add_user_to_account(user.id, Ecto.UUID.generate())

      assert "does not exist" in errors_on(changeset).account
    end
  end

  describe "remove_user_from_account/2" do
    test "removes user from account successfully" do
      user = user_fixture()
      account = account_fixture()
      member = member_fixture(user, account)

      assert {:ok, deleted_member} =
               MembersRepository.remove_user_from_account(user.id, account.id)

      assert deleted_member.id == member.id
      refute Repo.get(Member, member.id)
    end

    test "returns error when user is not member of account" do
      user = user_fixture()
      account = account_fixture()

      assert {:error, :not_found} =
               MembersRepository.remove_user_from_account(user.id, account.id)
    end

    test "prevents removal of last owner" do
      user = user_fixture()
      account = account_fixture()
      member_fixture(user, account, :owner)

      assert {:error, :last_owner} =
               MembersRepository.remove_user_from_account(user.id, account.id)

      assert Repo.get_by(Member, user_id: user.id, account_id: account.id)
    end

    test "allows removal of owner when multiple owners exist" do
      user1 = user_fixture()
      user2 = user_fixture()
      account = account_fixture()
      member_fixture(user1, account, :owner)
      member_fixture(user2, account, :owner)

      assert {:ok, _} = MembersRepository.remove_user_from_account(user1.id, account.id)
      refute Repo.get_by(Member, user_id: user1.id, account_id: account.id)
      assert Repo.get_by(Member, user_id: user2.id, account_id: account.id)
    end

    test "allows removal of admin or member regardless of count" do
      user1 = user_fixture()
      user2 = user_fixture()
      account = account_fixture()
      member_fixture(user1, account, :owner)
      member_fixture(user2, account, :admin)

      assert {:ok, _} = MembersRepository.remove_user_from_account(user2.id, account.id)
      refute Repo.get_by(Member, user_id: user2.id, account_id: account.id)
    end
  end

  describe "update_user_role/3" do
    test "updates user role successfully" do
      user = user_fixture()
      account = account_fixture()
      member = member_fixture(user, account, :member)

      assert {:ok, updated_member} =
               MembersRepository.update_user_role(user.id, account.id, :admin)

      assert updated_member.role == :admin
      assert updated_member.id == member.id
    end

    test "returns error when user is not member of account" do
      user = user_fixture()
      account = account_fixture()

      assert {:error, :not_found} =
               MembersRepository.update_user_role(user.id, account.id, :admin)
    end

    test "prevents changing last owner role" do
      user = user_fixture()
      account = account_fixture()
      member_fixture(user, account, :owner)

      assert {:error, changeset} = MembersRepository.update_user_role(user.id, account.id, :admin)
      assert "account must have at least one owner" in errors_on(changeset).role
    end

    test "allows changing owner role when multiple owners exist" do
      user1 = user_fixture()
      user2 = user_fixture()
      account = account_fixture()
      member_fixture(user1, account, :owner)
      member_fixture(user2, account, :owner)

      assert {:ok, updated_member} =
               MembersRepository.update_user_role(user1.id, account.id, :admin)

      assert updated_member.role == :admin
    end

    test "allows promoting user to owner" do
      user = user_fixture()
      account = account_fixture()
      member_fixture(user, account, :admin)

      assert {:ok, updated_member} =
               MembersRepository.update_user_role(user.id, account.id, :owner)

      assert updated_member.role == :owner
    end
  end

  describe "get_user_role/2" do
    test "returns user role when user is member of account" do
      user = user_fixture()
      account = account_fixture()
      member_fixture(user, account, :admin)

      assert MembersRepository.get_user_role(user.id, account.id) == :admin
    end

    test "returns nil when user is not member of account" do
      user = user_fixture()
      account = account_fixture()

      assert MembersRepository.get_user_role(user.id, account.id) == nil
    end
  end

  describe "user_has_account_access?/2" do
    test "returns true when user has access to account" do
      user = user_fixture()
      account = account_fixture()
      member_fixture(user, account)

      assert MembersRepository.user_has_account_access?(user.id, account.id) == true
    end

    test "returns false when user does not have access to account" do
      user = user_fixture()
      account = account_fixture()

      assert MembersRepository.user_has_account_access?(user.id, account.id) == false
    end
  end

  describe "can_add_user_to_account?/1" do
    test "always returns true" do
      account = account_fixture()
      assert MembersRepository.can_add_user_to_account?(account.id) == true
    end
  end

  describe "count_account_users/1" do
    test "returns count of users in account" do
      account = account_fixture()
      user1 = user_fixture()
      user2 = user_fixture()
      member_fixture(user1, account)
      member_fixture(user2, account)

      assert MembersRepository.count_account_users(account.id) == 2
    end

    test "returns 0 for account with no users" do
      account = account_fixture()

      assert MembersRepository.count_account_users(account.id) == 0
    end
  end

  describe "list_user_accounts/1" do
    test "returns accounts for user" do
      user = user_fixture()
      account1 = account_fixture()
      account2 = account_fixture()
      member_fixture(user, account1)
      member_fixture(user, account2)

      accounts = MembersRepository.list_user_accounts(user.id)
      account_ids = Enum.map(accounts, & &1.id)

      assert length(accounts) == 2
      assert account1.id in account_ids
      assert account2.id in account_ids
    end

    test "returns empty list for user with no accounts" do
      user = user_fixture()

      assert MembersRepository.list_user_accounts(user.id) == []
    end
  end

  describe "list_account_users/1" do
    test "returns users for account" do
      account = account_fixture()
      user1 = user_fixture()
      user2 = user_fixture()
      member_fixture(user1, account)
      member_fixture(user2, account)

      users = MembersRepository.list_account_users(account.id)
      user_ids = Enum.map(users, & &1.id)

      assert length(users) == 2
      assert user1.id in user_ids
      assert user2.id in user_ids
    end

    test "returns empty list for account with no users" do
      account = account_fixture()

      assert MembersRepository.list_account_users(account.id) == []
    end
  end

  describe "list_account_members/1" do
    test "returns members for account with users preloaded" do
      account = account_fixture()
      user1 = user_fixture()
      user2 = user_fixture()
      member1 = member_fixture(user1, account, :admin)
      member2 = member_fixture(user2, account, :member)

      members = MembersRepository.list_account_members(account.id)
      member_ids = Enum.map(members, & &1.id)

      assert length(members) == 2
      assert member1.id in member_ids
      assert member2.id in member_ids

      # Verify users are preloaded
      member_with_admin = Enum.find(members, &(&1.role == :admin))
      member_with_member = Enum.find(members, &(&1.role == :member))

      assert member_with_admin.user.id == user1.id
      assert member_with_member.user.id == user2.id
    end

    test "returns empty list for account with no members" do
      account = account_fixture()

      assert MembersRepository.list_account_members(account.id) == []
    end
  end

  describe "list_accounts_with_role/2" do
    test "returns accounts where user has specific role" do
      user = user_fixture()
      account1 = account_fixture()
      account2 = account_fixture()
      account3 = account_fixture()
      member_fixture(user, account1, :owner)
      member_fixture(user, account2, :admin)
      member_fixture(user, account3, :member)

      owner_accounts = MembersRepository.list_accounts_with_role(user.id, :owner)
      admin_accounts = MembersRepository.list_accounts_with_role(user.id, :admin)

      assert length(owner_accounts) == 1
      assert hd(owner_accounts).id == account1.id
      assert length(admin_accounts) == 1
      assert hd(admin_accounts).id == account2.id
    end

    test "returns empty list when user has no accounts with specified role" do
      user = user_fixture()

      assert MembersRepository.list_accounts_with_role(user.id, :owner) == []
    end
  end

  describe "query functions" do
    test "by_user/1 returns query for user's memberships" do
      user = user_fixture()
      account = account_fixture()
      member = member_fixture(user, account)

      query = MembersRepository.by_user(user.id)
      members = Repo.all(query)

      assert length(members) == 1
      assert hd(members).id == member.id
    end

    test "by_account/1 returns query for account's memberships" do
      user = user_fixture()
      account = account_fixture()
      member = member_fixture(user, account)

      query = MembersRepository.by_account(account.id)
      members = Repo.all(query)

      assert length(members) == 1
      assert hd(members).id == member.id
    end

    test "by_role/1 returns query for memberships with specific role" do
      user = user_fixture()
      account = account_fixture()
      member = member_fixture(user, account, :admin)

      query = MembersRepository.by_role(:admin)
      members = Repo.all(query)

      assert length(members) == 1
      assert hd(members).id == member.id
    end

    test "with_user_preloads/0 returns query with user preloaded" do
      user = user_fixture()
      account = account_fixture()
      member_fixture(user, account)

      query = MembersRepository.with_user_preloads()
      member = Repo.all(query) |> hd()

      assert member.user.id == user.id
      assert member.user.email == user.email
    end

    test "with_account_preloads/0 returns query with account preloaded" do
      user = user_fixture()
      account = account_fixture()
      member_fixture(user, account)

      query = MembersRepository.with_account_preloads()
      member = Repo.all(query) |> hd()

      assert member.account.id == account.id
      assert member.account.name == account.name
    end
  end
end
