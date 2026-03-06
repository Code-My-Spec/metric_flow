defmodule MetricFlow.Ai.ChatMessageTest do
  use MetricFlowTest.DataCase, async: true

  import Ecto.Changeset, only: [get_change: 2]
  import MetricFlowTest.UsersFixtures

  alias MetricFlow.Accounts.Account
  alias MetricFlow.Ai.ChatMessage
  alias MetricFlow.Ai.ChatSession
  alias MetricFlow.Repo

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp account_fixture do
    user = user_fixture()
    unique = System.unique_integer([:positive])

    %Account{}
    |> Account.creation_changeset(%{
      name: "Test Account #{unique}",
      slug: "test-account-#{unique}",
      type: "team",
      originator_user_id: user.id
    })
    |> Repo.insert!()
  end

  defp chat_session_fixture do
    user = user_fixture()
    account = account_fixture()

    %ChatSession{}
    |> ChatSession.changeset(%{
      user_id: user.id,
      account_id: account.id,
      context_type: :general
    })
    |> Repo.insert!()
  end

  defp valid_attrs(chat_session_id) do
    %{
      chat_session_id: chat_session_id,
      role: :user,
      content: "Hello, can you help me understand my metrics?"
    }
  end

  defp new_message do
    struct!(ChatMessage, [])
  end

  # ---------------------------------------------------------------------------
  # changeset/2
  # ---------------------------------------------------------------------------

  describe "changeset/2" do
    test "creates valid changeset for a :user message with all required fields" do
      session = chat_session_fixture()
      attrs = valid_attrs(session.id)

      changeset = ChatMessage.changeset(new_message(), attrs)

      assert changeset.valid?
    end

    test "creates valid changeset for an :assistant message with token_count" do
      session = chat_session_fixture()

      attrs = %{
        chat_session_id: session.id,
        role: :assistant,
        content: "Here is an analysis of your metrics.",
        token_count: 42
      }

      changeset = ChatMessage.changeset(new_message(), attrs)

      assert changeset.valid?
      assert get_change(changeset, :token_count) == 42
    end

    test "creates valid changeset for a :system message" do
      session = chat_session_fixture()

      attrs = %{
        chat_session_id: session.id,
        role: :system,
        content: "You are a marketing analytics assistant."
      }

      changeset = ChatMessage.changeset(new_message(), attrs)

      assert changeset.valid?
    end

    test "validates chat_session_id is required" do
      session = chat_session_fixture()
      attrs = Map.delete(valid_attrs(session.id), :chat_session_id)

      changeset = ChatMessage.changeset(new_message(), attrs)

      refute changeset.valid?
      assert %{chat_session_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates role is required" do
      session = chat_session_fixture()
      attrs = Map.delete(valid_attrs(session.id), :role)

      changeset = ChatMessage.changeset(new_message(), attrs)

      refute changeset.valid?
      assert %{role: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates content is required" do
      session = chat_session_fixture()
      attrs = Map.delete(valid_attrs(session.id), :content)

      changeset = ChatMessage.changeset(new_message(), attrs)

      refute changeset.valid?
      assert %{content: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects blank content (empty string)" do
      session = chat_session_fixture()
      attrs = %{valid_attrs(session.id) | content: ""}

      changeset = ChatMessage.changeset(new_message(), attrs)

      refute changeset.valid?
      assert %{content: [_]} = errors_on(changeset)
    end

    test "rejects an invalid role value not in the enum" do
      session = chat_session_fixture()
      attrs = %{valid_attrs(session.id) | role: :invalid_role}

      changeset = ChatMessage.changeset(new_message(), attrs)

      refute changeset.valid?
      assert %{role: [_]} = errors_on(changeset)
    end

    test "allows nil token_count for :user messages" do
      session = chat_session_fixture()
      attrs = Map.put(valid_attrs(session.id), :token_count, nil)

      changeset = ChatMessage.changeset(new_message(), attrs)

      assert changeset.valid?
    end

    test "allows nil token_count for :system messages" do
      session = chat_session_fixture()

      attrs = %{
        chat_session_id: session.id,
        role: :system,
        content: "You are a helpful assistant.",
        token_count: nil
      }

      changeset = ChatMessage.changeset(new_message(), attrs)

      assert changeset.valid?
    end

    test "accepts integer token_count for :assistant messages" do
      session = chat_session_fixture()

      attrs = %{
        chat_session_id: session.id,
        role: :assistant,
        content: "Your campaign ROI is 3.2x.",
        token_count: 128
      }

      changeset = ChatMessage.changeset(new_message(), attrs)

      assert changeset.valid?
      assert get_change(changeset, :token_count) == 128
    end

    test "validates chat_session association exists (assoc_constraint triggers on insert)" do
      attrs = valid_attrs(-1)

      {:error, changeset} =
        new_message()
        |> ChatMessage.changeset(attrs)
        |> Repo.insert()

      assert %{chat_session: ["does not exist"]} = errors_on(changeset)
    end
  end
end
