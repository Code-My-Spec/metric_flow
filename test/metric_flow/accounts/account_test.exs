defmodule MetricFlow.Accounts.AccountTest do
  use MetricFlowTest.DataCase, async: true

  import MetricFlowTest.UsersFixtures

  alias MetricFlow.Accounts.Account
  alias MetricFlow.Repo

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp unique_slug, do: "account-#{System.unique_integer([:positive])}"

  defp valid_creation_attrs(user) do
    %{
      name: "Acme Corp",
      slug: unique_slug(),
      type: "personal",
      originator_user_id: user.id
    }
  end

  defp valid_update_attrs do
    %{
      name: "Acme Corp Updated",
      slug: unique_slug()
    }
  end

  defp insert_account!(attrs) do
    %Account{}
    |> Account.creation_changeset(attrs)
    |> Repo.insert!()
  end

  # ---------------------------------------------------------------------------
  # changeset/2
  # ---------------------------------------------------------------------------

  describe "changeset/2" do
    setup do
      user = user_fixture()
      account = insert_account!(valid_creation_attrs(user))
      %{account: account}
    end

    test "returns a valid changeset for a valid name and slug", %{account: account} do
      attrs = valid_update_attrs()
      changeset = Account.changeset(account, attrs)

      assert changeset.valid?
    end

    test "returns an error when name is absent", %{account: account} do
      changeset = Account.changeset(account, %{name: nil, slug: unique_slug()})

      refute changeset.valid?
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "returns an error when name exceeds 255 characters", %{account: account} do
      too_long = String.duplicate("a", 256)
      changeset = Account.changeset(account, %{name: too_long, slug: unique_slug()})

      refute changeset.valid?
      assert "should be at most 255 character(s)" in errors_on(changeset).name
    end

    test "returns an error when slug is absent", %{account: account} do
      changeset = Account.changeset(account, %{name: "Valid Name", slug: nil})

      refute changeset.valid?
      assert %{slug: ["can't be blank"]} = errors_on(changeset)
    end

    test "returns an error when slug contains uppercase letters", %{account: account} do
      changeset = Account.changeset(account, %{name: "Valid Name", slug: "MySlug"})

      refute changeset.valid?
      assert %{slug: [_format_error]} = errors_on(changeset)
    end

    test "returns an error when slug contains spaces", %{account: account} do
      changeset = Account.changeset(account, %{name: "Valid Name", slug: "my slug"})

      refute changeset.valid?
      assert %{slug: [_format_error]} = errors_on(changeset)
    end

    test "returns an error when slug contains special characters other than hyphens", %{
      account: account
    } do
      changeset = Account.changeset(account, %{name: "Valid Name", slug: "my_slug!"})

      refute changeset.valid?
      assert %{slug: [_format_error]} = errors_on(changeset)
    end

    test "returns an error when slug is not unique", %{account: account} do
      user = user_fixture()
      existing_account = insert_account!(valid_creation_attrs(user))

      {:error, changeset} =
        account
        |> Account.changeset(%{name: "New Name", slug: existing_account.slug})
        |> Repo.update()

      assert %{slug: ["has already been taken"]} = errors_on(changeset)
    end

    test "does not cast type when provided in attrs", %{account: account} do
      original_type = account.type

      changeset =
        Account.changeset(account, %{name: "Valid Name", slug: unique_slug(), type: "team"})

      refute get_change(changeset, :type)
      assert changeset.data.type == original_type
    end

    test "does not cast originator_user_id when provided in attrs", %{account: account} do
      other_user = user_fixture()
      original_originator_id = account.originator_user_id

      changeset =
        Account.changeset(account, %{
          name: "Valid Name",
          slug: unique_slug(),
          originator_user_id: other_user.id
        })

      refute get_change(changeset, :originator_user_id)
      assert changeset.data.originator_user_id == original_originator_id
    end
  end

  # ---------------------------------------------------------------------------
  # creation_changeset/2
  # ---------------------------------------------------------------------------

  describe "creation_changeset/2" do
    setup do
      user = user_fixture()
      %{user: user}
    end

    test "returns a valid changeset for all valid fields", %{user: user} do
      attrs = valid_creation_attrs(user)
      changeset = Account.creation_changeset(%Account{}, attrs)

      assert changeset.valid?
    end

    test "returns an error when name is absent", %{user: user} do
      attrs = %{valid_creation_attrs(user) | name: nil}
      changeset = Account.creation_changeset(%Account{}, attrs)

      refute changeset.valid?
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "returns an error when slug is absent", %{user: user} do
      attrs = %{valid_creation_attrs(user) | slug: nil}
      changeset = Account.creation_changeset(%Account{}, attrs)

      refute changeset.valid?
      assert %{slug: ["can't be blank"]} = errors_on(changeset)
    end

    test "returns an error when slug format is invalid", %{user: user} do
      attrs = %{valid_creation_attrs(user) | slug: "Invalid Slug!"}
      changeset = Account.creation_changeset(%Account{}, attrs)

      refute changeset.valid?
      assert %{slug: [_format_error]} = errors_on(changeset)
    end

    test "returns an error when type is absent", %{user: user} do
      attrs = %{valid_creation_attrs(user) | type: nil}
      changeset = Account.creation_changeset(%Account{}, attrs)

      refute changeset.valid?
      assert %{type: ["can't be blank"]} = errors_on(changeset)
    end

    test "returns an error when type is not personal or team", %{user: user} do
      attrs = %{valid_creation_attrs(user) | type: "admin"}
      changeset = Account.creation_changeset(%Account{}, attrs)

      refute changeset.valid?
      assert %{type: ["is invalid"]} = errors_on(changeset)
    end

    test "returns an error when originator_user_id is absent", %{user: _user} do
      attrs = %{name: "Acme", slug: unique_slug(), type: "personal", originator_user_id: nil}
      changeset = Account.creation_changeset(%Account{}, attrs)

      refute changeset.valid?
      assert %{originator_user_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "returns an error when slug is not unique", %{user: user} do
      attrs = valid_creation_attrs(user)
      _existing = insert_account!(attrs)

      {:error, changeset} =
        %Account{}
        |> Account.creation_changeset(%{attrs | name: "Different Name"})
        |> Repo.insert()

      assert %{slug: ["has already been taken"]} = errors_on(changeset)
    end

    test "accepts type personal", %{user: user} do
      attrs = %{valid_creation_attrs(user) | type: "personal"}
      changeset = Account.creation_changeset(%Account{}, attrs)

      assert changeset.valid?
    end

    test "accepts type team", %{user: user} do
      attrs = %{valid_creation_attrs(user) | type: "team"}
      changeset = Account.creation_changeset(%Account{}, attrs)

      assert changeset.valid?
    end
  end
end
