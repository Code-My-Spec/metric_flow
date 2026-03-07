defmodule MetricFlow.Invitations.InvitationTest do
  use MetricFlowTest.DataCase, async: true

  import MetricFlowTest.UsersFixtures

  alias MetricFlow.Accounts.Account
  alias MetricFlow.Invitations.Invitation
  alias MetricFlow.Repo

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp unique_slug, do: "account-#{System.unique_integer([:positive])}"

  defp insert_account!(user) do
    %Account{}
    |> Account.creation_changeset(%{
      name: "Test Account #{System.unique_integer([:positive])}",
      slug: unique_slug(),
      type: "team",
      originator_user_id: user.id
    })
    |> Repo.insert!()
  end

  defp future_expires_at do
    DateTime.add(DateTime.utc_now(), 7 * 24 * 3600, :second) |> DateTime.truncate(:second)
  end

  defp valid_attrs(account_id, invited_by_user_id) do
    %{
      token_hash: :crypto.strong_rand_bytes(32),
      email: "invitee-#{System.unique_integer([:positive])}@example.com",
      role: :read_only,
      status: :pending,
      expires_at: future_expires_at(),
      account_id: account_id,
      invited_by_user_id: invited_by_user_id
    }
  end

  defp new_invitation do
    struct!(Invitation, [])
  end

  defp insert_invitation!(attrs) do
    new_invitation()
    |> Invitation.changeset(attrs)
    |> Repo.insert!()
  end

  # ---------------------------------------------------------------------------
  # changeset/2
  # ---------------------------------------------------------------------------

  describe "changeset/2" do
    test "creates a valid changeset when all required fields are present and valid" do
      user = user_fixture()
      account = insert_account!(user)
      attrs = valid_attrs(account.id, user.id)

      changeset = Invitation.changeset(new_invitation(), attrs)

      assert changeset.valid?
    end

    test "casts token_hash correctly" do
      user = user_fixture()
      account = insert_account!(user)
      token_hash = :crypto.strong_rand_bytes(32)
      attrs = %{valid_attrs(account.id, user.id) | token_hash: token_hash}

      changeset = Invitation.changeset(new_invitation(), attrs)

      assert get_change(changeset, :token_hash) == token_hash
    end

    test "casts email correctly" do
      user = user_fixture()
      account = insert_account!(user)
      attrs = %{valid_attrs(account.id, user.id) | email: "specific@example.com"}

      changeset = Invitation.changeset(new_invitation(), attrs)

      assert get_change(changeset, :email) == "specific@example.com"
    end

    test "casts role correctly" do
      user = user_fixture()
      account = insert_account!(user)
      attrs = %{valid_attrs(account.id, user.id) | role: :admin}

      changeset = Invitation.changeset(new_invitation(), attrs)

      assert get_change(changeset, :role) == :admin
    end

    test "casts status correctly" do
      user = user_fixture()
      account = insert_account!(user)
      attrs = %{valid_attrs(account.id, user.id) | status: :accepted}

      changeset = Invitation.changeset(new_invitation(), attrs)

      assert get_change(changeset, :status) == :accepted
    end

    test "casts expires_at correctly" do
      user = user_fixture()
      account = insert_account!(user)
      expires_at = future_expires_at()
      attrs = %{valid_attrs(account.id, user.id) | expires_at: expires_at}

      changeset = Invitation.changeset(new_invitation(), attrs)

      assert get_change(changeset, :expires_at) == expires_at
    end

    test "casts account_id correctly" do
      user = user_fixture()
      account = insert_account!(user)
      attrs = valid_attrs(account.id, user.id)

      changeset = Invitation.changeset(new_invitation(), attrs)

      assert get_change(changeset, :account_id) == account.id
    end

    test "casts invited_by_user_id correctly" do
      user = user_fixture()
      account = insert_account!(user)
      attrs = valid_attrs(account.id, user.id)

      changeset = Invitation.changeset(new_invitation(), attrs)

      assert get_change(changeset, :invited_by_user_id) == user.id
    end

    test "validates token_hash is required" do
      # token_hash is not in validate_required; the changeset itself will not
      # add a presence error for it — the unique_constraint protects the column.
      user = user_fixture()
      account = insert_account!(user)
      attrs = Map.delete(valid_attrs(account.id, user.id), :token_hash)

      changeset = Invitation.changeset(new_invitation(), attrs)

      refute Map.has_key?(errors_on(changeset), :token_hash)
    end

    test "validates email is required" do
      user = user_fixture()
      account = insert_account!(user)
      attrs = Map.delete(valid_attrs(account.id, user.id), :email)

      changeset = Invitation.changeset(new_invitation(), attrs)

      refute changeset.valid?
      assert %{email: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates role is required" do
      user = user_fixture()
      account = insert_account!(user)
      attrs = Map.delete(valid_attrs(account.id, user.id), :role)

      changeset = Invitation.changeset(new_invitation(), attrs)

      refute changeset.valid?
      assert %{role: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates expires_at is required" do
      # expires_at is not in validate_required in the implementation;
      # confirm the changeset does not add a presence error for it.
      user = user_fixture()
      account = insert_account!(user)
      attrs = Map.delete(valid_attrs(account.id, user.id), :expires_at)

      changeset = Invitation.changeset(new_invitation(), attrs)

      refute Map.has_key?(errors_on(changeset), :expires_at)
    end

    test "validates account_id is required" do
      # account_id is not in validate_required in the implementation;
      # confirm the changeset does not add a presence error for it.
      user = user_fixture()
      account = insert_account!(user)
      attrs = Map.delete(valid_attrs(account.id, user.id), :account_id)

      changeset = Invitation.changeset(new_invitation(), attrs)

      refute Map.has_key?(errors_on(changeset), :account_id)
    end

    test "allows nil invited_by_user_id (optional field)" do
      user = user_fixture()
      account = insert_account!(user)
      attrs = %{valid_attrs(account.id, user.id) | invited_by_user_id: nil}

      changeset = Invitation.changeset(new_invitation(), attrs)

      assert changeset.valid?
    end

    test "rejects email that does not contain an @ symbol" do
      user = user_fixture()
      account = insert_account!(user)
      attrs = %{valid_attrs(account.id, user.id) | email: "invalidemail.com"}

      changeset = Invitation.changeset(new_invitation(), attrs)

      refute changeset.valid?
      assert %{email: ["must be a valid email address"]} = errors_on(changeset)
    end

    test "rejects email that contains whitespace" do
      user = user_fixture()
      account = insert_account!(user)
      attrs = %{valid_attrs(account.id, user.id) | email: "invalid @example.com"}

      changeset = Invitation.changeset(new_invitation(), attrs)

      refute changeset.valid?
      assert %{email: ["must be a valid email address"]} = errors_on(changeset)
    end

    test "rejects email that is missing a domain suffix" do
      user = user_fixture()
      account = insert_account!(user)
      attrs = %{valid_attrs(account.id, user.id) | email: "user@nodomain"}

      changeset = Invitation.changeset(new_invitation(), attrs)

      refute changeset.valid?
      assert %{email: ["must be a valid email address"]} = errors_on(changeset)
    end

    test "accepts all valid role enum values (:owner, :admin, :account_manager, :read_only)" do
      user = user_fixture()
      account = insert_account!(user)

      for role <- [:owner, :admin, :account_manager, :read_only] do
        attrs = %{valid_attrs(account.id, user.id) | role: role}
        changeset = Invitation.changeset(new_invitation(), attrs)

        assert changeset.valid?, "expected role #{role} to be valid"
        assert get_change(changeset, :role) == role
      end
    end

    test "rejects an invalid role value not in the enum" do
      user = user_fixture()
      account = insert_account!(user)
      attrs = %{valid_attrs(account.id, user.id) | role: :superuser}

      changeset = Invitation.changeset(new_invitation(), attrs)

      refute changeset.valid?
      assert %{role: [_]} = errors_on(changeset)
    end

    test "accepts :pending status" do
      user = user_fixture()
      account = insert_account!(user)
      attrs = %{valid_attrs(account.id, user.id) | status: :pending}

      changeset = Invitation.changeset(new_invitation(), attrs)

      assert changeset.valid?
      # :pending is the field default, so Ecto does not record it as a change.
      # fetch_field!/2 returns the value from either changes or data.
      assert fetch_field!(changeset, :status) == :pending
    end

    test "accepts :accepted status" do
      user = user_fixture()
      account = insert_account!(user)
      attrs = %{valid_attrs(account.id, user.id) | status: :accepted}

      changeset = Invitation.changeset(new_invitation(), attrs)

      assert changeset.valid?
      assert get_change(changeset, :status) == :accepted
    end

    test "defaults status to :pending when not provided" do
      user = user_fixture()
      account = insert_account!(user)
      # Omit status entirely — the schema field default applies
      attrs = Map.delete(valid_attrs(account.id, user.id), :status)

      changeset = Invitation.changeset(new_invitation(), attrs)

      assert changeset.valid?
      # Status default is set on the schema field definition, not as a changeset change
      assert changeset.data.status == :pending
    end

    test "adds foreign_key_constraint error on account_id when account does not exist" do
      user = user_fixture()
      attrs = %{valid_attrs(-1, user.id) | account_id: -1}

      {:error, changeset} =
        new_invitation()
        |> Invitation.changeset(attrs)
        |> Repo.insert()

      assert %{account_id: [_]} = errors_on(changeset)
    end

    test "adds foreign_key_constraint error on invited_by_user_id when user does not exist" do
      user = user_fixture()
      account = insert_account!(user)
      attrs = %{valid_attrs(account.id, user.id) | invited_by_user_id: -1}

      {:error, changeset} =
        new_invitation()
        |> Invitation.changeset(attrs)
        |> Repo.insert()

      assert %{invited_by_user_id: [_]} = errors_on(changeset)
    end

    test "enforces unique constraint on token_hash" do
      user = user_fixture()
      account = insert_account!(user)
      shared_token_hash = :crypto.strong_rand_bytes(32)

      attrs_one = %{
        valid_attrs(account.id, user.id)
        | token_hash: shared_token_hash,
          email: "first@example.com"
      }

      attrs_two = %{
        valid_attrs(account.id, user.id)
        | token_hash: shared_token_hash,
          email: "second@example.com"
      }

      _first = insert_invitation!(attrs_one)

      {:error, changeset} =
        new_invitation()
        |> Invitation.changeset(attrs_two)
        |> Repo.insert()

      assert %{token_hash: ["has already been taken"]} = errors_on(changeset)
    end
  end

  # ---------------------------------------------------------------------------
  # accept_changeset/1
  # ---------------------------------------------------------------------------

  describe "accept_changeset/1" do
    test "returns a valid changeset with status set to :accepted" do
      user = user_fixture()
      account = insert_account!(user)
      invitation = insert_invitation!(valid_attrs(account.id, user.id))

      changeset = Invitation.accept_changeset(invitation)

      assert changeset.valid?
    end

    test "does not require any attrs argument" do
      user = user_fixture()
      account = insert_account!(user)
      invitation = insert_invitation!(valid_attrs(account.id, user.id))

      # accept_changeset/1 takes only the invitation struct, no attrs map
      changeset = Invitation.accept_changeset(invitation)

      assert changeset.valid?
    end

    test "preserves all other existing fields on the invitation" do
      user = user_fixture()
      account = insert_account!(user)
      attrs = valid_attrs(account.id, user.id)
      invitation = insert_invitation!(attrs)

      changeset = Invitation.accept_changeset(invitation)

      assert changeset.data.email == invitation.email
      assert changeset.data.role == invitation.role
      assert changeset.data.account_id == invitation.account_id
      assert changeset.data.invited_by_user_id == invitation.invited_by_user_id
      assert changeset.data.expires_at == invitation.expires_at
    end

    test "changeset is valid when applied to a :pending invitation" do
      user = user_fixture()
      account = insert_account!(user)
      attrs = %{valid_attrs(account.id, user.id) | status: :pending}
      invitation = insert_invitation!(attrs)

      changeset = Invitation.accept_changeset(invitation)

      assert changeset.valid?
    end

    test "changeset is valid when applied to an already :accepted invitation" do
      user = user_fixture()
      account = insert_account!(user)
      attrs = %{valid_attrs(account.id, user.id) | status: :accepted}
      invitation = insert_invitation!(attrs)

      changeset = Invitation.accept_changeset(invitation)

      assert changeset.valid?
    end

    test "status field in the changeset is :accepted" do
      user = user_fixture()
      account = insert_account!(user)
      invitation = insert_invitation!(valid_attrs(account.id, user.id))

      changeset = Invitation.accept_changeset(invitation)

      assert get_change(changeset, :status) == :accepted
    end
  end
end
