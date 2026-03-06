defmodule MetricFlow.Ai.ChatSessionTest do
  use MetricFlowTest.DataCase, async: true

  import MetricFlowTest.UsersFixtures

  alias MetricFlow.Accounts.Account
  alias MetricFlow.Ai.ChatSession
  alias MetricFlow.Repo

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp user_and_account_fixture do
    user = user_fixture()
    unique = System.unique_integer([:positive])

    account =
      %Account{}
      |> Account.creation_changeset(%{
        name: "Test Account #{unique}",
        slug: "test-account-#{unique}",
        type: "team",
        originator_user_id: user.id
      })
      |> Repo.insert!()

    {user, account}
  end

  defp valid_attrs(user_id, account_id) do
    %{
      user_id: user_id,
      account_id: account_id,
      context_type: :general
    }
  end

  defp new_session do
    struct!(ChatSession, [])
  end

  defp insert_session!(attrs) do
    new_session()
    |> ChatSession.changeset(attrs)
    |> Repo.insert!()
  end

  # ---------------------------------------------------------------------------
  # changeset/2
  # ---------------------------------------------------------------------------

  describe "changeset/2" do
    test "creates valid changeset with all required fields" do
      {user, account} = user_and_account_fixture()
      attrs = valid_attrs(user.id, account.id)

      changeset = ChatSession.changeset(new_session(), attrs)

      assert changeset.valid?
    end

    test "defaults status to :active when not provided" do
      {user, account} = user_and_account_fixture()
      attrs = valid_attrs(user.id, account.id)

      changeset = ChatSession.changeset(new_session(), attrs)

      assert changeset.valid?
      # Status defaults to :active via the schema default; get_field returns effective value
      assert get_field(changeset, :status) == :active
    end

    test "accepts explicit status of :active" do
      {user, account} = user_and_account_fixture()
      attrs = Map.put(valid_attrs(user.id, account.id), :status, :active)

      changeset = ChatSession.changeset(new_session(), attrs)

      assert changeset.valid?
      # Use get_field because casting :active over the :active default produces no change entry
      assert get_field(changeset, :status) == :active
    end

    test "accepts explicit status of :archived" do
      {user, account} = user_and_account_fixture()
      attrs = Map.put(valid_attrs(user.id, account.id), :status, :archived)

      changeset = ChatSession.changeset(new_session(), attrs)

      assert changeset.valid?
      assert get_change(changeset, :status) == :archived
    end

    test "rejects invalid status values" do
      {user, account} = user_and_account_fixture()
      attrs = Map.put(valid_attrs(user.id, account.id), :status, :deleted)

      changeset = ChatSession.changeset(new_session(), attrs)

      refute changeset.valid?
      assert %{status: [_]} = errors_on(changeset)
    end

    test "validates user_id is required" do
      {_user, account} = user_and_account_fixture()
      attrs = %{account_id: account.id, context_type: :general}

      changeset = ChatSession.changeset(new_session(), attrs)

      refute changeset.valid?
      assert %{user_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates account_id is required" do
      {user, _account} = user_and_account_fixture()
      attrs = %{user_id: user.id, context_type: :general}

      changeset = ChatSession.changeset(new_session(), attrs)

      refute changeset.valid?
      assert %{account_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates context_type is required" do
      {user, account} = user_and_account_fixture()
      attrs = %{user_id: user.id, account_id: account.id}

      changeset = ChatSession.changeset(new_session(), attrs)

      refute changeset.valid?
      assert %{context_type: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects invalid context_type values" do
      {user, account} = user_and_account_fixture()
      attrs = Map.put(valid_attrs(user.id, account.id), :context_type, :unknown)

      changeset = ChatSession.changeset(new_session(), attrs)

      refute changeset.valid?
      assert %{context_type: [_]} = errors_on(changeset)
    end

    test "accepts all valid context_type values" do
      {user, account} = user_and_account_fixture()

      for context_type <- [:general, :correlation, :metric, :dashboard] do
        attrs = Map.put(valid_attrs(user.id, account.id), :context_type, context_type)
        changeset = ChatSession.changeset(new_session(), attrs)

        assert changeset.valid?, "expected #{context_type} to be a valid context_type"
      end
    end

    test "allows nil title" do
      {user, account} = user_and_account_fixture()
      attrs = Map.put(valid_attrs(user.id, account.id), :title, nil)

      changeset = ChatSession.changeset(new_session(), attrs)

      assert changeset.valid?
    end

    test "accepts title up to 255 characters" do
      {user, account} = user_and_account_fixture()
      attrs = Map.put(valid_attrs(user.id, account.id), :title, String.duplicate("a", 255))

      changeset = ChatSession.changeset(new_session(), attrs)

      assert changeset.valid?
    end

    test "rejects title exceeding 255 characters" do
      {user, account} = user_and_account_fixture()
      attrs = Map.put(valid_attrs(user.id, account.id), :title, String.duplicate("a", 256))

      changeset = ChatSession.changeset(new_session(), attrs)

      refute changeset.valid?
      assert %{title: [_]} = errors_on(changeset)
    end

    test "allows nil context_id" do
      {user, account} = user_and_account_fixture()
      attrs = Map.put(valid_attrs(user.id, account.id), :context_id, nil)

      changeset = ChatSession.changeset(new_session(), attrs)

      assert changeset.valid?
    end

    test "accepts context_id when context_type is :correlation" do
      {user, account} = user_and_account_fixture()

      attrs =
        valid_attrs(user.id, account.id)
        |> Map.put(:context_type, :correlation)
        |> Map.put(:context_id, 42)

      changeset = ChatSession.changeset(new_session(), attrs)

      assert changeset.valid?
      assert get_change(changeset, :context_id) == 42
    end

    test "accepts context_id when context_type is :metric" do
      {user, account} = user_and_account_fixture()

      attrs =
        valid_attrs(user.id, account.id)
        |> Map.put(:context_type, :metric)
        |> Map.put(:context_id, 99)

      changeset = ChatSession.changeset(new_session(), attrs)

      assert changeset.valid?
      assert get_change(changeset, :context_id) == 99
    end

    test "accepts context_id when context_type is :dashboard" do
      {user, account} = user_and_account_fixture()

      attrs =
        valid_attrs(user.id, account.id)
        |> Map.put(:context_type, :dashboard)
        |> Map.put(:context_id, 7)

      changeset = ChatSession.changeset(new_session(), attrs)

      assert changeset.valid?
      assert get_change(changeset, :context_id) == 7
    end

    test "validates user association exists (assoc_constraint triggers on insert)" do
      {_user, account} = user_and_account_fixture()
      attrs = %{user_id: -1, account_id: account.id, context_type: :general}

      {:error, changeset} =
        new_session()
        |> ChatSession.changeset(attrs)
        |> Repo.insert()

      assert %{user: ["does not exist"]} = errors_on(changeset)
    end

    test "validates account association exists (assoc_constraint triggers on insert)" do
      {user, _account} = user_and_account_fixture()
      attrs = %{user_id: user.id, account_id: -1, context_type: :general}

      {:error, changeset} =
        new_session()
        |> ChatSession.changeset(attrs)
        |> Repo.insert()

      assert %{account: ["does not exist"]} = errors_on(changeset)
    end
  end

  # ---------------------------------------------------------------------------
  # archive_changeset/1
  # ---------------------------------------------------------------------------

  describe "archive_changeset/1" do
    test "returns valid changeset that sets status to :archived when session is :active" do
      {user, account} = user_and_account_fixture()
      session = insert_session!(valid_attrs(user.id, account.id))

      assert session.status == :active

      changeset = ChatSession.archive_changeset(session)

      assert changeset.valid?
      assert get_change(changeset, :status) == :archived
    end

    test "returns invalid changeset with error when session status is already :archived" do
      {user, account} = user_and_account_fixture()

      session =
        insert_session!(
          valid_attrs(user.id, account.id) |> Map.put(:status, :archived)
        )

      changeset = ChatSession.archive_changeset(session)

      refute changeset.valid?
      assert %{status: [_]} = errors_on(changeset)
    end

    test "does not require any additional attributes" do
      {user, account} = user_and_account_fixture()
      session = insert_session!(valid_attrs(user.id, account.id))

      changeset = ChatSession.archive_changeset(session)

      assert changeset.valid?
    end
  end
end
