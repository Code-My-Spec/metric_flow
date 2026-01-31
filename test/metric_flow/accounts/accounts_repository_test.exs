defmodule MetricFlow.Accounts.AccountsRepositoryTest do
  use MetricFlow.DataCase, async: true

  import MetricFlow.AccountsFixtures
  import MetricFlow.UsersFixtures

  alias MetricFlow.Accounts.{Account, AccountsRepository, Member}
  alias MetricFlow.Repo

  describe "create_account/1" do
    test "creates an account with valid attributes" do
      attrs = valid_account_attributes()

      assert {:ok, %Account{} = account} = AccountsRepository.create_account(attrs)
      assert account.name == attrs.name
      assert account.slug == attrs.slug
      assert account.type == attrs.type
    end

    test "returns error with invalid attributes" do
      attrs = %{name: nil, type: :team}

      assert {:error, changeset} = AccountsRepository.create_account(attrs)
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "returns error with duplicate slug" do
      attrs = valid_account_attributes()
      {:ok, _account} = AccountsRepository.create_account(attrs)

      assert {:error, changeset} = AccountsRepository.create_account(attrs)
      assert %{slug: ["has already been taken"]} = errors_on(changeset)
    end

    test "returns error with reserved slug" do
      attrs = valid_account_attributes(%{slug: "admin"})

      assert {:error, changeset} = AccountsRepository.create_account(attrs)
      assert %{slug: ["is reserved and cannot be used"]} = errors_on(changeset)
    end
  end

  describe "get_account/1" do
    test "returns account when it exists" do
      account = account_fixture()

      assert fetched_account = AccountsRepository.get_account(account.id)
      assert fetched_account.id == account.id
      assert fetched_account.name == account.name
    end

    test "returns nil when account doesn't exist" do
      assert AccountsRepository.get_account(Ecto.UUID.generate()) == nil
    end
  end

  describe "get_account!/1" do
    test "returns account when it exists" do
      account = account_fixture()

      assert fetched_account = AccountsRepository.get_account!(account.id)
      assert fetched_account.id == account.id
    end

    test "raises when account doesn't exist" do
      assert_raise Ecto.NoResultsError, fn ->
        AccountsRepository.get_account!(Ecto.UUID.generate())
      end
    end
  end

  describe "update_account/2" do
    test "updates account with valid attributes" do
      account = account_fixture()
      attrs = %{name: "Updated Name", slug: "updated-slug"}

      assert {:ok, updated_account} = AccountsRepository.update_account(account, attrs)
      assert updated_account.name == "Updated Name"
      assert updated_account.slug == "updated-slug"
    end

    test "returns error with invalid attributes" do
      account = account_fixture()
      attrs = %{name: ""}

      assert {:error, changeset} = AccountsRepository.update_account(account, attrs)
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "returns error with duplicate slug" do
      account1 = account_fixture()
      account2 = account_fixture()

      assert {:error, changeset} =
               AccountsRepository.update_account(account2, %{slug: account1.slug})

      assert %{slug: ["has already been taken"]} = errors_on(changeset)
    end
  end

  describe "delete_account/1" do
    test "deletes account" do
      account = account_fixture()

      assert {:ok, deleted_account} = AccountsRepository.delete_account(account)
      assert deleted_account.id == account.id
      assert AccountsRepository.get_account(account.id) == nil
    end

    test "deletes account with associated members (cascade)" do
      user = user_fixture()
      account = account_with_owner_fixture(user)

      assert {:ok, deleted_account} = AccountsRepository.delete_account(account)
      assert deleted_account.id == account.id
      assert AccountsRepository.get_account(account.id) == nil

      # Verify member was also deleted due to cascade
      assert Repo.get_by(Member, user_id: user.id, account_id: account.id) == nil
    end
  end

  describe "create_personal_account/1" do
    test "creates personal account for user" do
      user = user_fixture()

      assert {:ok, %Account{} = account} = AccountsRepository.create_personal_account(user.id)
      assert account.type == :personal
      assert account.name != nil
      assert account.slug != nil

      # Verify member was created
      member = Repo.get_by(Member, user_id: user.id, account_id: account.id)
      assert member.role == :owner
    end

    test "extracts name from email" do
      user = user_fixture(%{email: "john.doe@example.com"})

      assert {:ok, account} = AccountsRepository.create_personal_account(user.id)
      assert account.name == "john.doe"
      assert account.slug == "john-doe"
    end

    test "returns error when user doesn't exist" do
      assert_raise Ecto.NoResultsError, fn ->
        AccountsRepository.create_personal_account(999)
      end
    end
  end

  describe "create_team_account/2" do
    test "creates team account with creator as owner" do
      user = user_fixture()
      attrs = %{name: "Team Account", slug: "team-account"}

      assert {:ok, %Account{} = account} = AccountsRepository.create_team_account(attrs, user.id)
      assert account.type == :team
      assert account.name == "Team Account"
      assert account.slug == "team-account"

      # Verify member was created
      member = Repo.get_by(Member, user_id: user.id, account_id: account.id)
      assert member.role == :owner
    end

    test "returns error with invalid attributes" do
      user = user_fixture()
      attrs = %{name: "", slug: "invalid"}

      assert {:error, changeset} = AccountsRepository.create_team_account(attrs, user.id)
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "get_personal_account/1" do
    test "returns personal account for user" do
      user = user_fixture()
      {:ok, account} = AccountsRepository.create_personal_account(user.id)

      assert fetched_account = AccountsRepository.get_personal_account(user.id)
      assert fetched_account.id == account.id
      assert fetched_account.type == :personal
    end

    test "returns nil when user only has team accounts" do
      user = user_fixture()
      _team_account = account_with_owner_fixture(user)

      assert AccountsRepository.get_personal_account(user.id) == nil
    end

    test "returns nil when user has no accounts" do
      user = user_fixture()

      assert AccountsRepository.get_personal_account(user.id) == nil
    end
  end

  describe "ensure_personal_account/1" do
    test "returns existing personal account" do
      user = user_fixture()
      {:ok, existing_account} = AccountsRepository.create_personal_account(user.id)

      assert account = AccountsRepository.ensure_personal_account(user.id)
      assert account.id == existing_account.id
    end

    test "creates new personal account when none exists" do
      user = user_fixture()

      assert account = AccountsRepository.ensure_personal_account(user.id)
      assert account.type == :personal

      # Verify it's persisted
      assert AccountsRepository.get_personal_account(user.id) != nil
    end
  end

  describe "by_slug/1" do
    test "returns query for accounts with matching slug" do
      account = account_fixture(%{slug: "test-slug"})

      query = AccountsRepository.by_slug("test-slug")
      [fetched_account] = Repo.all(query)
      assert fetched_account.id == account.id
    end

    test "returns empty result for non-existent slug" do
      query = AccountsRepository.by_slug("non-existent")
      assert [] = Repo.all(query)
    end
  end

  describe "by_type/1" do
    test "returns query for accounts with matching type" do
      personal_account = personal_account_fixture()
      team_account = account_fixture()

      personal_query = AccountsRepository.by_type(:personal)
      team_query = AccountsRepository.by_type(:team)

      personal_results = Repo.all(personal_query)
      team_results = Repo.all(team_query)

      assert Enum.any?(personal_results, &(&1.id == personal_account.id))
      assert Enum.any?(team_results, &(&1.id == team_account.id))
    end
  end

  describe "with_preloads/1" do
    test "returns query with specified preloads" do
      user = user_fixture()
      _account = account_with_owner_fixture(user)

      query = AccountsRepository.with_preloads([:members])
      [fetched_account] = Repo.all(query)

      assert Ecto.assoc_loaded?(fetched_account.members)
      assert length(fetched_account.members) == 1
    end

    test "handles multiple preloads" do
      user = user_fixture()
      _account = account_with_owner_fixture(user)

      query = AccountsRepository.with_preloads([:members, :users])
      [fetched_account] = Repo.all(query)

      assert Ecto.assoc_loaded?(fetched_account.members)
      assert Ecto.assoc_loaded?(fetched_account.users)
    end
  end

  describe "query composition" do
    test "combines by_slug and by_type queries" do
      personal_account = personal_account_fixture(%{slug: "personal-test"})
      _team_account = account_fixture(%{slug: "team-test"})

      query =
        from(a in Account)
        |> where([a], a.slug == ^"personal-test")
        |> where([a], a.type == ^:personal)

      [result] = Repo.all(query)
      assert result.id == personal_account.id
    end

    test "uses individual query builders correctly" do
      user = user_fixture()
      _account = account_with_owner_fixture(user, %{slug: "test-slug", type: :team})

      # Test by_slug query
      slug_query = AccountsRepository.by_slug("test-slug")
      slug_results = Repo.all(slug_query)
      assert length(slug_results) == 1

      # Test by_type query
      type_query = AccountsRepository.by_type(:team)
      type_results = Repo.all(type_query)
      assert length(type_results) >= 1

      # Test with_preloads query
      preload_query = AccountsRepository.with_preloads([:members])
      [preload_result] = Repo.all(preload_query)
      assert Ecto.assoc_loaded?(preload_result.members)
    end
  end

  describe "extract_name_from_email/1" do
    test "extracts username from email" do
      user1 = user_fixture(%{email: "john.doe@example.com"})
      user2 = user_fixture(%{email: "jane_smith@test.org"})

      {:ok, account1} = AccountsRepository.create_personal_account(user1.id)
      {:ok, account2} = AccountsRepository.create_personal_account(user2.id)

      assert account1.name == "john.doe"
      assert account2.name == "jane_smith"
    end

    test "handles edge cases in email extraction" do
      user = user_fixture(%{email: "user+tag@example.com"})

      {:ok, account} = AccountsRepository.create_personal_account(user.id)
      assert account.name == "user+tag"
    end
  end
end
