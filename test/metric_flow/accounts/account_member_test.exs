defmodule MetricFlow.Accounts.AccountMemberTest do
  use MetricFlowTest.DataCase, async: true

  import MetricFlowTest.UsersFixtures

  alias MetricFlow.Accounts.AccountMember

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp unique_account_name, do: "Account #{System.unique_integer([:positive])}"

  defp insert_account_direct(user_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    {:ok, result} =
      Repo.query(
        "INSERT INTO accounts (name, slug, type, originator_user_id, inserted_at, updated_at) " <>
          "VALUES ($1, $2, $3, $4, $5, $6) RETURNING id",
        [
          unique_account_name(),
          "slug-#{System.unique_integer([:positive])}",
          "standard",
          user_id,
          now,
          now
        ]
      )

    %{id: result.rows |> List.first() |> List.first()}
  end

  defp account_and_user_fixture do
    user = user_fixture()
    account = insert_account_direct(user.id)
    {account, user}
  end

  defp valid_attrs(%{account_id: account_id, user_id: user_id}) do
    %{account_id: account_id, user_id: user_id, role: :owner}
  end

  # struct!/2 is evaluated at runtime, so this compiles even before
  # AccountMember exists. An alias alone does not require the module to be
  # loaded at compile time.
  defp new_account_member do
    struct!(AccountMember, [])
  end

  # ---------------------------------------------------------------------------
  # changeset/2
  # ---------------------------------------------------------------------------

  describe "changeset/2" do
    test "returns a valid changeset with all required fields present" do
      {account, user} = account_and_user_fixture()
      attrs = valid_attrs(%{account_id: account.id, user_id: user.id})

      changeset = AccountMember.changeset(new_account_member(), attrs)

      assert changeset.valid?
    end

    test "casts account_id from attrs" do
      {account, user} = account_and_user_fixture()
      attrs = valid_attrs(%{account_id: account.id, user_id: user.id})

      changeset = AccountMember.changeset(new_account_member(), attrs)

      assert get_change(changeset, :account_id) == account.id
    end

    test "casts user_id from attrs" do
      {account, user} = account_and_user_fixture()
      attrs = valid_attrs(%{account_id: account.id, user_id: user.id})

      changeset = AccountMember.changeset(new_account_member(), attrs)

      assert get_change(changeset, :user_id) == user.id
    end

    test "casts role from attrs" do
      {account, user} = account_and_user_fixture()
      attrs = valid_attrs(%{account_id: account.id, user_id: user.id})

      changeset = AccountMember.changeset(new_account_member(), attrs)

      assert get_change(changeset, :role) == :owner
    end

    test "returns invalid changeset when account_id is missing" do
      user = user_fixture()
      attrs = %{user_id: user.id, role: :owner}

      changeset = AccountMember.changeset(new_account_member(), attrs)

      refute changeset.valid?
      assert %{account_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "returns invalid changeset when user_id is missing" do
      {account, _user} = account_and_user_fixture()
      attrs = %{account_id: account.id, role: :owner}

      changeset = AccountMember.changeset(new_account_member(), attrs)

      refute changeset.valid?
      assert %{user_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "returns invalid changeset when role is missing" do
      {account, user} = account_and_user_fixture()
      attrs = %{account_id: account.id, user_id: user.id}

      changeset = AccountMember.changeset(new_account_member(), attrs)

      refute changeset.valid?
      assert %{role: ["can't be blank"]} = errors_on(changeset)
    end

    test "returns invalid changeset when role is not a valid enum value" do
      {account, user} = account_and_user_fixture()
      attrs = %{account_id: account.id, user_id: user.id, role: :superuser}

      changeset = AccountMember.changeset(new_account_member(), attrs)

      refute changeset.valid?
      assert %{role: [_]} = errors_on(changeset)
    end

    test "accepts owner as a valid role value" do
      {account, user} = account_and_user_fixture()
      attrs = %{account_id: account.id, user_id: user.id, role: :owner}

      changeset = AccountMember.changeset(new_account_member(), attrs)

      assert changeset.valid?
      assert get_change(changeset, :role) == :owner
    end

    test "accepts admin as a valid role value" do
      {account, user} = account_and_user_fixture()
      attrs = %{account_id: account.id, user_id: user.id, role: :admin}

      changeset = AccountMember.changeset(new_account_member(), attrs)

      assert changeset.valid?
      assert get_change(changeset, :role) == :admin
    end

    test "accepts account_manager as a valid role value" do
      {account, user} = account_and_user_fixture()
      attrs = %{account_id: account.id, user_id: user.id, role: :account_manager}

      changeset = AccountMember.changeset(new_account_member(), attrs)

      assert changeset.valid?
      assert get_change(changeset, :role) == :account_manager
    end

    test "accepts read_only as a valid role value" do
      {account, user} = account_and_user_fixture()
      attrs = %{account_id: account.id, user_id: user.id, role: :read_only}

      changeset = AccountMember.changeset(new_account_member(), attrs)

      assert changeset.valid?
      assert get_change(changeset, :role) == :read_only
    end

    test "enforces unique constraint on account_id and user_id combination" do
      {account, user} = account_and_user_fixture()
      attrs = valid_attrs(%{account_id: account.id, user_id: user.id})

      {:ok, _} =
        new_account_member()
        |> AccountMember.changeset(attrs)
        |> Repo.insert()

      {:error, changeset} =
        new_account_member()
        |> AccountMember.changeset(attrs)
        |> Repo.insert()

      assert %{account_id: ["has already been taken"]} = errors_on(changeset)
    end
  end

  # ---------------------------------------------------------------------------
  # role_changeset/2
  # ---------------------------------------------------------------------------

  describe "role_changeset/2" do
    setup do
      {account, user} = account_and_user_fixture()
      attrs = valid_attrs(%{account_id: account.id, user_id: user.id})

      {:ok, member} =
        new_account_member()
        |> AccountMember.changeset(attrs)
        |> Repo.insert()

      %{member: member, account: account, user: user}
    end

    test "returns a valid changeset when role is a valid enum value", %{member: member} do
      changeset = AccountMember.role_changeset(member, %{role: :admin})

      assert changeset.valid?
    end

    test "accepts owner as a valid role value", %{member: member} do
      changeset = AccountMember.role_changeset(member, %{role: :owner})

      assert changeset.valid?
      assert get_change(changeset, :role) == :owner
    end

    test "accepts admin as a valid role value", %{member: member} do
      changeset = AccountMember.role_changeset(member, %{role: :admin})

      assert changeset.valid?
      assert get_change(changeset, :role) == :admin
    end

    test "accepts account_manager as a valid role value", %{member: member} do
      changeset = AccountMember.role_changeset(member, %{role: :account_manager})

      assert changeset.valid?
      assert get_change(changeset, :role) == :account_manager
    end

    test "accepts read_only as a valid role value", %{member: member} do
      changeset = AccountMember.role_changeset(member, %{role: :read_only})

      assert changeset.valid?
      assert get_change(changeset, :role) == :read_only
    end

    test "returns invalid changeset when role is not a valid enum value", %{member: member} do
      changeset = AccountMember.role_changeset(member, %{role: :superuser})

      refute changeset.valid?
      assert %{role: [_]} = errors_on(changeset)
    end

    test "does not cast or modify account_id", %{member: member} do
      original_account_id = member.account_id

      changeset =
        AccountMember.role_changeset(member, %{role: :admin, account_id: 0})

      assert get_change(changeset, :account_id) == nil
      assert changeset.data.account_id == original_account_id
    end

    test "does not cast or modify user_id", %{member: member} do
      original_user_id = member.user_id

      changeset =
        AccountMember.role_changeset(member, %{role: :admin, user_id: 0})

      assert get_change(changeset, :user_id) == nil
      assert changeset.data.user_id == original_user_id
    end

    test "returns invalid changeset when role is missing", %{member: member} do
      changeset = AccountMember.role_changeset(member, %{})

      refute changeset.valid?
      assert %{role: ["can't be blank"]} = errors_on(changeset)
    end
  end
end
