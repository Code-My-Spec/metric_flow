defmodule MetricFlow.AccountsTest do
  use MetricFlowTest.DataCase
  alias MetricFlow.Accounts

  import MetricFlowTest.AccountsFixtures
  import MetricFlowTest.UsersFixtures

  describe "subscribe_account/1" do
    test "subscribes to account notifications for user" do
      user = user_fixture()
      scope = user_scope_fixture(user)

      assert :ok = Accounts.subscribe_account(scope)
    end
  end

  describe "subscribe_member/1" do
    test "subscribes to member notifications for user" do
      user = user_fixture()
      scope = user_scope_fixture(user)

      assert :ok = Accounts.subscribe_member(scope)
    end
  end

  describe "list_accounts/1" do
    test "returns user's accounts" do
      user = user_fixture()
      scope = user_scope_fixture(user)
      account = account_with_owner_fixture(user)

      accounts = Accounts.list_accounts(scope)

      assert length(accounts) == 1
      assert hd(accounts).id == account.id
    end

    test "returns empty list when user has no accounts" do
      user = user_fixture()
      scope = user_scope_fixture(user)

      accounts = Accounts.list_accounts(scope)

      assert accounts == []
    end
  end

  describe "get_account!/2" do
    test "returns account when user has access" do
      user = user_fixture()
      scope = user_scope_fixture(user)
      account = account_with_owner_fixture(user)

      result = Accounts.get_account!(scope, account.id)

      assert result.id == account.id
    end

    test "raises when account doesn't exist" do
      user = user_fixture()
      scope = user_scope_fixture(user)

      assert_raise Ecto.NoResultsError, fn ->
        Accounts.get_account!(scope, Ecto.UUID.generate())
      end
    end
  end

  describe "create_account/2" do
    test "creates account with valid attributes" do
      user = user_fixture()
      scope = user_scope_fixture(user)
      attrs = valid_account_attributes()

      assert {:ok, account} = Accounts.create_account(scope, attrs)
      assert account.name == attrs.name
      assert account.slug == attrs.slug
      assert account.type == attrs.type
    end

    test "broadcasts account creation" do
      user = user_fixture()
      scope = user_scope_fixture(user)
      Accounts.subscribe_account(scope)

      attrs = valid_account_attributes()
      {:ok, account} = Accounts.create_account(scope, attrs)

      assert_receive {:created, ^account}
    end

    test "returns error with invalid attributes" do
      user = user_fixture()
      scope = user_scope_fixture(user)
      attrs = %{name: nil}

      assert {:error, _changeset} = Accounts.create_account(scope, attrs)
    end
  end

  describe "create_personal_account/1" do
    test "creates personal account for user" do
      user = user_fixture()
      scope = user_scope_fixture(user)

      assert {:ok, account} = Accounts.create_personal_account(scope)
      assert account.type == :personal
    end

    test "broadcasts personal account creation" do
      user = user_fixture()
      scope = user_scope_fixture(user)
      Accounts.subscribe_account(scope)

      {:ok, account} = Accounts.create_personal_account(scope)

      assert_receive {:created, ^account}
    end
  end

  describe "create_team_account/2" do
    test "creates team account with user as owner" do
      user = user_fixture()
      scope = user_scope_fixture(user)
      attrs = valid_account_attributes()

      assert {:ok, account} = Accounts.create_team_account(scope, attrs)
      assert account.type == :team
    end

    test "broadcasts team account creation" do
      user = user_fixture()
      scope = user_scope_fixture(user)
      Accounts.subscribe_account(scope)

      attrs = valid_account_attributes()
      {:ok, account} = Accounts.create_team_account(scope, attrs)

      assert_receive {:created, ^account}
    end
  end

  describe "update_account/3" do
    test "updates account with valid attributes" do
      user = user_fixture()
      scope = user_scope_fixture(user)
      account = account_with_owner_fixture(user)

      attrs = %{name: "Updated Name"}
      assert {:ok, updated_account} = Accounts.update_account(scope, account, attrs)
      assert updated_account.name == "Updated Name"
    end

    test "broadcasts account update" do
      user = user_fixture()
      scope = user_scope_fixture(user)
      account = account_with_owner_fixture(user)
      Accounts.subscribe_account(scope)

      attrs = %{name: "Updated Name"}
      {:ok, updated_account} = Accounts.update_account(scope, account, attrs)

      assert_receive {:updated, ^updated_account}
    end

    test "returns error with invalid attributes" do
      user = user_fixture()
      scope = user_scope_fixture(user)
      account = account_with_owner_fixture(user)

      attrs = %{name: nil}
      assert {:error, _changeset} = Accounts.update_account(scope, account, attrs)
    end
  end

  describe "delete_account/2" do
    test "deletes account" do
      user = user_fixture()
      scope = user_scope_fixture(user)
      account = account_with_owner_fixture(user)

      assert {:ok, deleted_account} = Accounts.delete_account(scope, account)
      assert deleted_account.id == account.id
    end

    test "broadcasts account deletion" do
      user = user_fixture()
      scope = user_scope_fixture(user)
      account = account_with_owner_fixture(user)
      Accounts.subscribe_account(scope)

      {:ok, deleted_account} = Accounts.delete_account(scope, account)

      assert_receive {:deleted, ^deleted_account}
    end
  end

  describe "change_account/3" do
    test "returns changeset for account" do
      user = user_fixture()
      scope = user_scope_fixture(user)
      account = account_with_owner_fixture(user)

      changeset = Accounts.change_account(scope, account)

      assert %Ecto.Changeset{} = changeset
    end

    test "returns changeset with attributes" do
      user = user_fixture()
      scope = user_scope_fixture(user)
      account = account_with_owner_fixture(user)

      attrs = %{name: "New Name"}
      changeset = Accounts.change_account(scope, account, attrs)

      assert changeset.changes.name == "New Name"
    end
  end

  describe "get_personal_account/1" do
    test "returns personal account for user" do
      user = user_fixture()
      scope = user_scope_fixture(user)
      personal_account = personal_account_with_owner_fixture(user)

      result = Accounts.get_personal_account(scope)

      assert result.id == personal_account.id
    end

    test "returns nil when user has no personal account" do
      user = user_fixture()
      scope = user_scope_fixture(user)

      result = Accounts.get_personal_account(scope)

      assert result == nil
    end
  end

  describe "ensure_personal_account/1" do
    test "returns existing personal account" do
      user = user_fixture()
      scope = user_scope_fixture(user)
      personal_account = personal_account_with_owner_fixture(user)

      result = Accounts.ensure_personal_account(scope)

      assert result.id == personal_account.id
    end

    test "creates personal account when none exists" do
      user = user_fixture()
      scope = user_scope_fixture(user)

      result = Accounts.ensure_personal_account(scope)

      assert result.type == :personal
    end
  end

  describe "list_account_members/2" do
    test "returns account members" do
      user = user_fixture()
      scope = user_scope_fixture(user)
      account = account_with_owner_fixture(user)

      members = Accounts.list_account_members(scope, account.id)

      assert length(members) == 1
      assert hd(members).user_id == user.id
    end

    test "returns only owner for account with owner" do
      user = user_fixture()
      scope = user_scope_fixture(user)
      account = account_with_owner_fixture(user)

      members = Accounts.list_account_members(scope, account.id)
      result = members |> Enum.at(0) |> Map.get(:user)

      assert result == user
    end
  end

  describe "add_user_to_account/4" do
    test "adds user to account with default member role" do
      owner = user_fixture()
      owner_scope = user_scope_fixture(owner)
      account = account_with_owner_fixture(owner)
      user = user_fixture()

      assert {:ok, member} = Accounts.add_user_to_account(owner_scope, user.id, account.id)
      assert member.role == :member
    end

    test "adds user to account with specified role" do
      owner = user_fixture()
      owner_scope = user_scope_fixture(owner)
      account = account_with_owner_fixture(owner)
      user = user_fixture()

      assert {:ok, member} =
               Accounts.add_user_to_account(owner_scope, user.id, account.id, :admin)

      assert member.role == :admin
    end

    test "broadcasts member creation" do
      owner = user_fixture()
      owner_scope = user_scope_fixture(owner)
      account = account_with_owner_fixture(owner)
      user = user_fixture()
      Accounts.subscribe_member(owner_scope)

      {:ok, member} = Accounts.add_user_to_account(owner_scope, user.id, account.id)

      assert_receive {:created, ^member}
    end
  end

  describe "remove_user_from_account/3" do
    test "removes user from account" do
      owner = user_fixture()
      owner_scope = user_scope_fixture(owner)
      account = account_with_owner_fixture(owner)
      user = user_fixture()
      {:ok, member} = Accounts.add_user_to_account(owner_scope, user.id, account.id)

      assert {:ok, removed_member} =
               Accounts.remove_user_from_account(owner_scope, user.id, account.id)

      assert removed_member.id == member.id
    end

    test "broadcasts member deletion" do
      owner = user_fixture()
      owner_scope = user_scope_fixture(owner)
      account = account_with_owner_fixture(owner)
      user = user_fixture()
      {:ok, _member} = Accounts.add_user_to_account(owner_scope, user.id, account.id)
      Accounts.subscribe_member(owner_scope)

      {:ok, removed_member} = Accounts.remove_user_from_account(owner_scope, user.id, account.id)

      assert_receive {:deleted, ^removed_member}
    end
  end

  describe "update_user_role/4" do
    test "updates user role in account" do
      owner = user_fixture()
      owner_scope = user_scope_fixture(owner)
      account = account_with_owner_fixture(owner)
      user = user_fixture()
      {:ok, _member} = Accounts.add_user_to_account(owner_scope, user.id, account.id)

      assert {:ok, updated_member} =
               Accounts.update_user_role(owner_scope, user.id, account.id, :admin)

      assert updated_member.role == :admin
    end

    test "broadcasts member update" do
      owner = user_fixture()
      owner_scope = user_scope_fixture(owner)
      account = account_with_owner_fixture(owner)
      user = user_fixture()
      {:ok, _member} = Accounts.add_user_to_account(owner_scope, user.id, account.id)
      Accounts.subscribe_member(owner_scope)

      {:ok, updated_member} = Accounts.update_user_role(owner_scope, user.id, account.id, :admin)

      assert_receive {:updated, ^updated_member}
    end
  end

  describe "get_user_role/3" do
    test "returns user role in account" do
      owner = user_fixture()
      owner_scope = user_scope_fixture(owner)
      account = account_with_owner_fixture(owner)
      user = user_fixture()
      {:ok, _member} = Accounts.add_user_to_account(owner_scope, user.id, account.id, :admin)

      role = Accounts.get_user_role(owner_scope, user.id, account.id)

      assert role == :admin
    end

    test "returns nil when user has no role in account" do
      owner = user_fixture()
      owner_scope = user_scope_fixture(owner)
      account = account_with_owner_fixture(owner)
      user = user_fixture()

      role = Accounts.get_user_role(owner_scope, user.id, account.id)

      assert role == nil
    end
  end

  describe "user_has_account_access?/2" do
    test "returns true when user has access to account" do
      user = user_fixture()
      scope = user_scope_fixture(user)
      account = account_with_owner_fixture(user)

      assert Accounts.user_has_account_access?(scope, account.id) == true
    end

    test "returns false when user has no access to account" do
      user = user_fixture()
      scope = user_scope_fixture(user)
      account = account_fixture()

      assert Accounts.user_has_account_access?(scope, account.id) == false
    end
  end
end
