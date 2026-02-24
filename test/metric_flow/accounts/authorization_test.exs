defmodule MetricFlow.Accounts.AuthorizationTest do
  use MetricFlowTest.DataCase, async: true

  import MetricFlowTest.UsersFixtures

  alias MetricFlow.Accounts.Account
  alias MetricFlow.Accounts.AccountMember
  alias MetricFlow.Accounts.Authorization
  alias MetricFlow.Users.Scope

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp unique_slug, do: "account-#{System.unique_integer([:positive])}"

  defp insert_account!(user) do
    %Account{}
    |> Account.creation_changeset(%{
      name: "Test Account",
      slug: unique_slug(),
      type: "team",
      originator_user_id: user.id
    })
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

  defp setup_member(role) do
    user = user_fixture()
    scope = Scope.for_user(user)
    owner_user = user_fixture()
    account = insert_account!(owner_user)
    insert_member!(account, user, role)
    %{scope: scope, account: account}
  end

  # ---------------------------------------------------------------------------
  # can?/3
  # ---------------------------------------------------------------------------

  describe "can?/3" do
    # :update_account

    test "returns true for owner performing :update_account" do
      %{scope: scope, account: account} = setup_member(:owner)

      assert Authorization.can?(scope, :update_account, %{account_id: account.id})
    end

    test "returns true for admin performing :update_account" do
      %{scope: scope, account: account} = setup_member(:admin)

      assert Authorization.can?(scope, :update_account, %{account_id: account.id})
    end

    test "returns false for account_manager performing :update_account" do
      %{scope: scope, account: account} = setup_member(:account_manager)

      refute Authorization.can?(scope, :update_account, %{account_id: account.id})
    end

    test "returns false for read_only performing :update_account" do
      %{scope: scope, account: account} = setup_member(:read_only)

      refute Authorization.can?(scope, :update_account, %{account_id: account.id})
    end

    # :delete_account

    test "returns true for owner performing :delete_account" do
      %{scope: scope, account: account} = setup_member(:owner)

      assert Authorization.can?(scope, :delete_account, %{account_id: account.id})
    end

    test "returns false for admin performing :delete_account" do
      %{scope: scope, account: account} = setup_member(:admin)

      refute Authorization.can?(scope, :delete_account, %{account_id: account.id})
    end

    test "returns false for account_manager performing :delete_account" do
      %{scope: scope, account: account} = setup_member(:account_manager)

      refute Authorization.can?(scope, :delete_account, %{account_id: account.id})
    end

    test "returns false for read_only performing :delete_account" do
      %{scope: scope, account: account} = setup_member(:read_only)

      refute Authorization.can?(scope, :delete_account, %{account_id: account.id})
    end

    # :add_member

    test "returns true for owner performing :add_member with any target_role" do
      %{scope: scope, account: account} = setup_member(:owner)

      assert Authorization.can?(scope, :add_member, %{account_id: account.id, target_role: :owner})
    end

    test "returns false for admin performing :add_member with target_role :admin" do
      %{scope: scope, account: account} = setup_member(:admin)

      refute Authorization.can?(scope, :add_member, %{account_id: account.id, target_role: :admin})
    end

    test "returns true for admin performing :add_member with target_role :account_manager" do
      %{scope: scope, account: account} = setup_member(:admin)

      assert Authorization.can?(scope, :add_member, %{
               account_id: account.id,
               target_role: :account_manager
             })
    end

    test "returns true for admin performing :add_member with target_role :read_only" do
      %{scope: scope, account: account} = setup_member(:admin)

      assert Authorization.can?(scope, :add_member, %{
               account_id: account.id,
               target_role: :read_only
             })
    end

    test "returns false for admin performing :add_member with target_role :owner" do
      %{scope: scope, account: account} = setup_member(:admin)

      refute Authorization.can?(scope, :add_member, %{account_id: account.id, target_role: :owner})
    end

    test "returns false for account_manager performing :add_member" do
      %{scope: scope, account: account} = setup_member(:account_manager)

      refute Authorization.can?(scope, :add_member, %{account_id: account.id})
    end

    test "returns false for read_only performing :add_member" do
      %{scope: scope, account: account} = setup_member(:read_only)

      refute Authorization.can?(scope, :add_member, %{account_id: account.id})
    end

    # :remove_member

    test "returns true for owner performing :remove_member" do
      %{scope: scope, account: account} = setup_member(:owner)

      assert Authorization.can?(scope, :remove_member, %{account_id: account.id})
    end

    test "returns true for admin performing :remove_member" do
      %{scope: scope, account: account} = setup_member(:admin)

      assert Authorization.can?(scope, :remove_member, %{account_id: account.id})
    end

    test "returns false for account_manager performing :remove_member" do
      %{scope: scope, account: account} = setup_member(:account_manager)

      refute Authorization.can?(scope, :remove_member, %{account_id: account.id})
    end

    test "returns false for read_only performing :remove_member" do
      %{scope: scope, account: account} = setup_member(:read_only)

      refute Authorization.can?(scope, :remove_member, %{account_id: account.id})
    end

    # :update_user_role

    test "returns true for owner performing :update_user_role with any target_role" do
      %{scope: scope, account: account} = setup_member(:owner)

      assert Authorization.can?(scope, :update_user_role, %{
               account_id: account.id,
               target_role: :owner
             })
    end

    test "returns false for admin performing :update_user_role with target_role :admin" do
      %{scope: scope, account: account} = setup_member(:admin)

      refute Authorization.can?(scope, :update_user_role, %{
               account_id: account.id,
               target_role: :admin
             })
    end

    test "returns true for admin performing :update_user_role with target_role :account_manager" do
      %{scope: scope, account: account} = setup_member(:admin)

      assert Authorization.can?(scope, :update_user_role, %{
               account_id: account.id,
               target_role: :account_manager
             })
    end

    test "returns true for admin performing :update_user_role with target_role :read_only" do
      %{scope: scope, account: account} = setup_member(:admin)

      assert Authorization.can?(scope, :update_user_role, %{
               account_id: account.id,
               target_role: :read_only
             })
    end

    test "returns false for admin performing :update_user_role with target_role :owner" do
      %{scope: scope, account: account} = setup_member(:admin)

      refute Authorization.can?(scope, :update_user_role, %{
               account_id: account.id,
               target_role: :owner
             })
    end

    test "returns false for account_manager performing :update_user_role" do
      %{scope: scope, account: account} = setup_member(:account_manager)

      refute Authorization.can?(scope, :update_user_role, %{account_id: account.id})
    end

    test "returns false for read_only performing :update_user_role" do
      %{scope: scope, account: account} = setup_member(:read_only)

      refute Authorization.can?(scope, :update_user_role, %{account_id: account.id})
    end

    # Non-member and edge cases

    test "returns false when the calling user is not a member of the account" do
      non_member_user = user_fixture()
      scope = Scope.for_user(non_member_user)

      owner_user = user_fixture()
      account = insert_account!(owner_user)

      refute Authorization.can?(scope, :update_account, %{account_id: account.id})
    end

    test "returns false for an unrecognised action atom" do
      %{scope: scope, account: account} = setup_member(:owner)

      refute Authorization.can?(scope, :fly_to_the_moon, %{account_id: account.id})
    end

    test "returns false when scope.user is nil" do
      owner_user = user_fixture()
      account = insert_account!(owner_user)
      nil_scope = %Scope{user: nil}

      refute Authorization.can?(nil_scope, :update_account, %{account_id: account.id})
    end
  end
end
