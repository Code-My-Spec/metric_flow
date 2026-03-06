defmodule MetricFlow.Ai.AiRepositoryTest do
  use MetricFlowTest.DataCase, async: true

  import MetricFlowTest.AiFixtures

  alias MetricFlow.Accounts
  alias MetricFlow.Ai.AiRepository
  alias MetricFlow.Ai.ChatMessage
  alias MetricFlow.Ai.ChatSession
  alias MetricFlow.Ai.SuggestionFeedback

  # ---------------------------------------------------------------------------
  # list_insights/2
  # ---------------------------------------------------------------------------

  describe "list_insights/2" do
    test "returns list of insights scoped to account" do
      {_user, scope} = user_with_scope()
      account_id = Accounts.get_personal_account_id(scope)
      insert_insight!(account_id)
      insert_insight!(account_id, %{suggestion_type: :optimization, summary: "Optimize targeting"})

      results = AiRepository.list_insights(scope)

      assert length(results) == 2
    end

    test "returns empty list when no insights exist for account" do
      {_user, scope} = user_with_scope()

      assert AiRepository.list_insights(scope) == []
    end

    test "filters by suggestion_type when option provided" do
      {_user, scope} = user_with_scope()
      account_id = Accounts.get_personal_account_id(scope)
      insert_insight!(account_id, %{suggestion_type: :budget_increase})
      insert_insight!(account_id, %{suggestion_type: :optimization, summary: "Optimize targeting"})

      results = AiRepository.list_insights(scope, suggestion_type: :budget_increase)

      assert length(results) == 1
      assert hd(results).suggestion_type == :budget_increase
    end

    test "filters by correlation_result_id when option provided" do
      {_user, scope} = user_with_scope()
      account_id = Accounts.get_personal_account_id(scope)
      correlation_result = insert_correlation_result!(account_id)
      insert_insight!(account_id, %{correlation_result_id: correlation_result.id})
      insert_insight!(account_id, %{suggestion_type: :optimization, summary: "Optimize targeting"})

      results = AiRepository.list_insights(scope, correlation_result_id: correlation_result.id)

      assert length(results) == 1
      assert hd(results).correlation_result_id == correlation_result.id
    end

    test "orders by generated_at descending" do
      {_user, scope} = user_with_scope()
      account_id = Accounts.get_personal_account_id(scope)
      older_at = DateTime.add(DateTime.utc_now(), -3600, :second)
      newer_at = DateTime.utc_now()

      insert_insight!(account_id, %{generated_at: older_at, summary: "Older insight"})
      insert_insight!(account_id, %{generated_at: newer_at, summary: "Newer insight"})

      results = AiRepository.list_insights(scope)
      generated_ats = Enum.map(results, & &1.generated_at)

      assert generated_ats == Enum.sort(generated_ats, {:desc, DateTime})
    end

    test "applies limit and offset correctly" do
      {_user, scope} = user_with_scope()
      account_id = Accounts.get_personal_account_id(scope)

      base_time = DateTime.utc_now()

      insert_insight!(account_id, %{generated_at: DateTime.add(base_time, -1, :second), summary: "Second newest"})
      insert_insight!(account_id, %{generated_at: DateTime.add(base_time, -2, :second), summary: "Third newest"})
      insert_insight!(account_id, %{generated_at: base_time, summary: "Newest"})

      limited = AiRepository.list_insights(scope, limit: 2)
      assert length(limited) == 2

      offset_results = AiRepository.list_insights(scope, limit: 2, offset: 1)
      assert length(offset_results) == 2
      assert hd(offset_results).summary == "Second newest"
    end

    test "does not return insights from other accounts" do
      {_user, scope} = user_with_scope()
      account_id = Accounts.get_personal_account_id(scope)

      {_other_user, other_scope} = user_with_scope()
      other_account_id = Accounts.get_personal_account_id(other_scope)

      insert_insight!(account_id)
      insert_insight!(other_account_id, %{suggestion_type: :optimization, summary: "Other account insight"})

      results = AiRepository.list_insights(scope)

      assert length(results) == 1
      assert hd(results).account_id == account_id
    end
  end

  # ---------------------------------------------------------------------------
  # get_insight/2
  # ---------------------------------------------------------------------------

  describe "get_insight/2" do
    test "returns ok tuple with insight when found" do
      {_user, scope} = user_with_scope()
      account_id = Accounts.get_personal_account_id(scope)
      insight = insert_insight!(account_id)

      assert {:ok, found} = AiRepository.get_insight(scope, insight.id)
      assert found.id == insight.id
      assert found.summary == insight.summary
    end

    test "returns error :not_found when insight does not exist" do
      {_user, scope} = user_with_scope()

      assert {:error, :not_found} = AiRepository.get_insight(scope, -1)
    end

    test "returns error :not_found when insight belongs to a different account" do
      {_user, scope} = user_with_scope()

      {_other_user, other_scope} = user_with_scope()
      other_account_id = Accounts.get_personal_account_id(other_scope)
      other_insight = insert_insight!(other_account_id)

      assert {:error, :not_found} = AiRepository.get_insight(scope, other_insight.id)
    end
  end

  # ---------------------------------------------------------------------------
  # create_insight/2
  # ---------------------------------------------------------------------------

  describe "create_insight/2" do
    test "returns ok tuple with created insight on success" do
      {_user, scope} = user_with_scope()
      account_id = Accounts.get_personal_account_id(scope)
      attrs = valid_insight_attrs(account_id) |> Map.delete(:account_id)

      assert {:ok, insight} = AiRepository.create_insight(scope, attrs)
      assert insight.id != nil
      assert insight.summary == "Increase Google Ads budget to improve revenue"
    end

    test "sets account_id from Scope" do
      {_user, scope} = user_with_scope()
      account_id = Accounts.get_personal_account_id(scope)
      attrs = valid_insight_attrs(account_id) |> Map.delete(:account_id)

      assert {:ok, insight} = AiRepository.create_insight(scope, attrs)
      assert insight.account_id == account_id
    end

    test "stores content, summary, and suggestion_type from attrs" do
      {_user, scope} = user_with_scope()
      account_id = Accounts.get_personal_account_id(scope)

      attrs =
        valid_insight_attrs(account_id,
          %{
            content: "Custom content for this insight.",
            summary: "Custom summary",
            suggestion_type: :optimization
          }
        )
        |> Map.delete(:account_id)

      assert {:ok, insight} = AiRepository.create_insight(scope, attrs)
      assert insight.content == "Custom content for this insight."
      assert insight.summary == "Custom summary"
      assert insight.suggestion_type == :optimization
    end

    test "stores optional correlation_result_id when provided" do
      {_user, scope} = user_with_scope()
      account_id = Accounts.get_personal_account_id(scope)
      correlation_result = insert_correlation_result!(account_id)

      attrs =
        valid_insight_attrs(account_id, %{correlation_result_id: correlation_result.id})
        |> Map.delete(:account_id)

      assert {:ok, insight} = AiRepository.create_insight(scope, attrs)
      assert insight.correlation_result_id == correlation_result.id
    end

    test "stores confidence value from attrs" do
      {_user, scope} = user_with_scope()
      account_id = Accounts.get_personal_account_id(scope)
      attrs = valid_insight_attrs(account_id, %{confidence: 0.95}) |> Map.delete(:account_id)

      assert {:ok, insight} = AiRepository.create_insight(scope, attrs)
      assert insight.confidence == 0.95
    end

    test "returns error changeset when required fields are missing" do
      {_user, scope} = user_with_scope()

      assert {:error, changeset} = AiRepository.create_insight(scope, %{})
      refute changeset.valid?
    end

    test "returns error changeset when suggestion_type is invalid" do
      {_user, scope} = user_with_scope()
      account_id = Accounts.get_personal_account_id(scope)
      attrs = valid_insight_attrs(account_id, %{suggestion_type: :not_a_type}) |> Map.delete(:account_id)

      assert {:error, changeset} = AiRepository.create_insight(scope, attrs)
      refute changeset.valid?
    end

    test "returns error changeset when confidence is outside the 0.0-1.0 range" do
      {_user, scope} = user_with_scope()
      account_id = Accounts.get_personal_account_id(scope)
      attrs = valid_insight_attrs(account_id, %{confidence: 1.5}) |> Map.delete(:account_id)

      assert {:error, changeset} = AiRepository.create_insight(scope, attrs)
      refute changeset.valid?
    end
  end

  # ---------------------------------------------------------------------------
  # list_chat_sessions/1
  # ---------------------------------------------------------------------------

  describe "list_chat_sessions/1" do
    test "returns list of chat sessions for scoped user" do
      {user, scope} = user_with_scope()
      account_id = Accounts.get_personal_account_id(scope)
      insert_chat_session!(user.id, account_id)
      insert_chat_session!(user.id, account_id, %{title: "Second session"})

      results = AiRepository.list_chat_sessions(scope)

      assert length(results) == 2
    end

    test "returns empty list when user has no sessions" do
      {_user, scope} = user_with_scope()

      assert AiRepository.list_chat_sessions(scope) == []
    end

    test "orders by updated_at descending" do
      {user, scope} = user_with_scope()
      account_id = Accounts.get_personal_account_id(scope)

      older = insert_chat_session!(user.id, account_id, %{title: "Older session"})
      newer = insert_chat_session!(user.id, account_id, %{title: "Newer session"})

      # Force a different updated_at by updating the older session after the newer one
      Repo.update_all(
        from(s in ChatSession, where: s.id == ^older.id),
        set: [updated_at: DateTime.add(DateTime.utc_now(), -3600, :second)]
      )

      results = AiRepository.list_chat_sessions(scope)
      result_ids = Enum.map(results, & &1.id)

      assert result_ids == [newer.id, older.id]
    end

    test "does not return sessions belonging to other users" do
      {user, scope} = user_with_scope()
      account_id = Accounts.get_personal_account_id(scope)

      {other_user, other_scope} = user_with_scope()
      other_account_id = Accounts.get_personal_account_id(other_scope)

      insert_chat_session!(user.id, account_id)
      insert_chat_session!(other_user.id, other_account_id, %{title: "Other user session"})

      results = AiRepository.list_chat_sessions(scope)

      assert length(results) == 1
      assert hd(results).user_id == user.id
    end
  end

  # ---------------------------------------------------------------------------
  # get_chat_session/2
  # ---------------------------------------------------------------------------

  describe "get_chat_session/2" do
    test "returns ok tuple with ChatSession when found" do
      {user, scope} = user_with_scope()
      account_id = Accounts.get_personal_account_id(scope)
      session = insert_chat_session!(user.id, account_id, %{title: "My session"})

      assert {:ok, found} = AiRepository.get_chat_session(scope, session.id)
      assert found.id == session.id
      assert found.title == "My session"
    end

    test "preloads messages ordered by inserted_at ascending" do
      {user, scope} = user_with_scope()
      account_id = Accounts.get_personal_account_id(scope)
      session = insert_chat_session!(user.id, account_id)

      first_msg = insert_chat_message!(session.id, %{role: :user, content: "First message"})
      second_msg = insert_chat_message!(session.id, %{role: :assistant, content: "Second message"})

      # Ensure different inserted_at values
      Repo.update_all(
        from(m in ChatMessage, where: m.id == ^first_msg.id),
        set: [inserted_at: DateTime.add(DateTime.utc_now(), -60, :second)]
      )

      assert {:ok, found} = AiRepository.get_chat_session(scope, session.id)
      assert length(found.chat_messages) == 2

      message_ids = Enum.map(found.chat_messages, & &1.id)
      assert message_ids == [first_msg.id, second_msg.id]
    end

    test "returns error :not_found when session does not exist" do
      {_user, scope} = user_with_scope()

      assert {:error, :not_found} = AiRepository.get_chat_session(scope, -1)
    end

    test "returns error :not_found when session belongs to a different user" do
      {_user, scope} = user_with_scope()

      {other_user, other_scope} = user_with_scope()
      other_account_id = Accounts.get_personal_account_id(other_scope)
      other_session = insert_chat_session!(other_user.id, other_account_id)

      assert {:error, :not_found} = AiRepository.get_chat_session(scope, other_session.id)
    end
  end

  # ---------------------------------------------------------------------------
  # create_chat_session/2
  # ---------------------------------------------------------------------------

  describe "create_chat_session/2" do
    test "returns ok tuple with ChatSession on success" do
      {_user, scope} = user_with_scope()

      assert {:ok, session} = AiRepository.create_chat_session(scope, %{context_type: :general})
      assert session.id != nil
      assert session.context_type == :general
    end

    test "sets user_id from Scope" do
      {user, scope} = user_with_scope()

      assert {:ok, session} = AiRepository.create_chat_session(scope, %{context_type: :general})
      assert session.user_id == user.id
    end

    test "sets account_id from Scope" do
      {_user, scope} = user_with_scope()
      account_id = Accounts.get_personal_account_id(scope)

      assert {:ok, session} = AiRepository.create_chat_session(scope, %{context_type: :general})
      assert session.account_id == account_id
    end

    test "stores context_type from attrs" do
      {_user, scope} = user_with_scope()

      assert {:ok, session} = AiRepository.create_chat_session(scope, %{context_type: :correlation})
      assert session.context_type == :correlation
    end

    test "allows optional context_id to be nil" do
      {_user, scope} = user_with_scope()

      assert {:ok, session} = AiRepository.create_chat_session(scope, %{context_type: :general, context_id: nil})
      assert session.context_id == nil
    end

    test "stores context_id when provided" do
      {_user, scope} = user_with_scope()
      account_id = Accounts.get_personal_account_id(scope)
      correlation_result = insert_correlation_result!(account_id)

      attrs = %{context_type: :correlation, context_id: correlation_result.id}

      assert {:ok, session} = AiRepository.create_chat_session(scope, attrs)
      assert session.context_id == correlation_result.id
    end

    test "returns error changeset when context_type is invalid" do
      {_user, scope} = user_with_scope()

      assert {:error, changeset} = AiRepository.create_chat_session(scope, %{context_type: :not_a_type})
      refute changeset.valid?
    end

    test "returns error changeset when required fields are missing" do
      {_user, scope} = user_with_scope()

      assert {:error, changeset} = AiRepository.create_chat_session(scope, %{})
      refute changeset.valid?
    end
  end

  # ---------------------------------------------------------------------------
  # update_chat_session/3
  # ---------------------------------------------------------------------------

  describe "update_chat_session/3" do
    test "returns ok tuple with updated session on success" do
      {user, scope} = user_with_scope()
      account_id = Accounts.get_personal_account_id(scope)
      session = insert_chat_session!(user.id, account_id)

      assert {:ok, updated} = AiRepository.update_chat_session(scope, session, %{title: "New title"})
      assert updated.id == session.id
      assert updated.title == "New title"
    end

    test "updates title field" do
      {user, scope} = user_with_scope()
      account_id = Accounts.get_personal_account_id(scope)
      session = insert_chat_session!(user.id, account_id, %{title: "Old title"})

      assert {:ok, updated} = AiRepository.update_chat_session(scope, session, %{title: "Updated title"})
      assert updated.title == "Updated title"
    end

    test "updates status field" do
      {user, scope} = user_with_scope()
      account_id = Accounts.get_personal_account_id(scope)
      session = insert_chat_session!(user.id, account_id)

      assert {:ok, updated} = AiRepository.update_chat_session(scope, session, %{status: :archived})
      assert updated.status == :archived
    end

    test "returns error changeset when status is invalid" do
      {user, scope} = user_with_scope()
      account_id = Accounts.get_personal_account_id(scope)
      session = insert_chat_session!(user.id, account_id)

      assert {:error, changeset} = AiRepository.update_chat_session(scope, session, %{status: :not_a_status})
      refute changeset.valid?
    end
  end

  # ---------------------------------------------------------------------------
  # create_chat_message/2
  # ---------------------------------------------------------------------------

  describe "create_chat_message/2" do
    test "returns ok tuple with ChatMessage on success" do
      {user, scope} = user_with_scope()
      account_id = Accounts.get_personal_account_id(scope)
      session = insert_chat_session!(user.id, account_id)

      attrs = %{chat_session_id: session.id, role: :user, content: "What metrics are trending?"}

      assert {:ok, message} = AiRepository.create_chat_message(scope, attrs)
      assert message.id != nil
      assert message.content == "What metrics are trending?"
    end

    test "stores chat_session_id, role, and content from attrs" do
      {user, scope} = user_with_scope()
      account_id = Accounts.get_personal_account_id(scope)
      session = insert_chat_session!(user.id, account_id)

      attrs = %{chat_session_id: session.id, role: :assistant, content: "Revenue is up 15% this month."}

      assert {:ok, message} = AiRepository.create_chat_message(scope, attrs)
      assert message.chat_session_id == session.id
      assert message.role == :assistant
      assert message.content == "Revenue is up 15% this month."
    end

    test "stores optional token_count when provided" do
      {user, scope} = user_with_scope()
      account_id = Accounts.get_personal_account_id(scope)
      session = insert_chat_session!(user.id, account_id)

      attrs = %{chat_session_id: session.id, role: :assistant, content: "Here is the analysis.", token_count: 42}

      assert {:ok, message} = AiRepository.create_chat_message(scope, attrs)
      assert message.token_count == 42
    end

    test "returns error changeset when role is invalid" do
      {user, scope} = user_with_scope()
      account_id = Accounts.get_personal_account_id(scope)
      session = insert_chat_session!(user.id, account_id)

      attrs = %{chat_session_id: session.id, role: :not_a_role, content: "Some content."}

      assert {:error, changeset} = AiRepository.create_chat_message(scope, attrs)
      refute changeset.valid?
    end

    test "returns error changeset when required fields are missing" do
      {_user, scope} = user_with_scope()

      assert {:error, changeset} = AiRepository.create_chat_message(scope, %{})
      refute changeset.valid?
    end
  end

  # ---------------------------------------------------------------------------
  # upsert_feedback/3
  # ---------------------------------------------------------------------------

  describe "upsert_feedback/3" do
    test "returns ok tuple with SuggestionFeedback on success" do
      {_user, scope} = user_with_scope()
      account_id = Accounts.get_personal_account_id(scope)
      insight = insert_insight!(account_id)

      assert {:ok, feedback} = AiRepository.upsert_feedback(scope, insight.id, %{rating: :helpful})
      assert feedback.id != nil
      assert feedback.rating == :helpful
    end

    test "creates new feedback when none exists for the user and insight" do
      {user, scope} = user_with_scope()
      account_id = Accounts.get_personal_account_id(scope)
      insight = insert_insight!(account_id)

      assert {:ok, feedback} = AiRepository.upsert_feedback(scope, insight.id, %{rating: :helpful})
      assert feedback.insight_id == insight.id
      assert feedback.user_id == user.id
    end

    test "updates rating and comment when feedback already exists for the user and insight" do
      {user, scope} = user_with_scope()
      account_id = Accounts.get_personal_account_id(scope)
      insight = insert_insight!(account_id)

      {:ok, _first} = AiRepository.upsert_feedback(scope, insight.id, %{rating: :helpful, comment: "Great insight!"})
      {:ok, updated} = AiRepository.upsert_feedback(scope, insight.id, %{rating: :not_helpful, comment: "Changed my mind."})

      assert updated.rating == :not_helpful
      assert updated.comment == "Changed my mind."

      all_feedback = Repo.all(from f in SuggestionFeedback, where: f.insight_id == ^insight.id and f.user_id == ^user.id)
      assert length(all_feedback) == 1
    end

    test "sets user_id from Scope" do
      {user, scope} = user_with_scope()
      account_id = Accounts.get_personal_account_id(scope)
      insight = insert_insight!(account_id)

      assert {:ok, feedback} = AiRepository.upsert_feedback(scope, insight.id, %{rating: :helpful})
      assert feedback.user_id == user.id
    end

    test "stores insight_id from the second argument" do
      {_user, scope} = user_with_scope()
      account_id = Accounts.get_personal_account_id(scope)
      insight = insert_insight!(account_id)

      assert {:ok, feedback} = AiRepository.upsert_feedback(scope, insight.id, %{rating: :not_helpful})
      assert feedback.insight_id == insight.id
    end

    test "allows nil comment" do
      {_user, scope} = user_with_scope()
      account_id = Accounts.get_personal_account_id(scope)
      insight = insert_insight!(account_id)

      assert {:ok, feedback} = AiRepository.upsert_feedback(scope, insight.id, %{rating: :helpful, comment: nil})
      assert feedback.comment == nil
    end

    test "returns error changeset when rating is invalid" do
      {_user, scope} = user_with_scope()
      account_id = Accounts.get_personal_account_id(scope)
      insight = insert_insight!(account_id)

      assert {:error, changeset} = AiRepository.upsert_feedback(scope, insight.id, %{rating: :not_a_rating})
      refute changeset.valid?
    end
  end

  # ---------------------------------------------------------------------------
  # get_feedback_for_insight/2
  # ---------------------------------------------------------------------------

  describe "get_feedback_for_insight/2" do
    test "returns SuggestionFeedback when the user has submitted feedback for the insight" do
      {user, scope} = user_with_scope()
      account_id = Accounts.get_personal_account_id(scope)
      insight = insert_insight!(account_id)
      insert_suggestion_feedback!(insight.id, user.id, %{rating: :helpful})

      result = AiRepository.get_feedback_for_insight(scope, insight.id)

      assert %SuggestionFeedback{} = result
      assert result.insight_id == insight.id
      assert result.user_id == user.id
      assert result.rating == :helpful
    end

    test "returns nil when the user has not submitted feedback for the insight" do
      {_user, scope} = user_with_scope()
      account_id = Accounts.get_personal_account_id(scope)
      insight = insert_insight!(account_id)

      assert AiRepository.get_feedback_for_insight(scope, insight.id) == nil
    end

    test "returns nil when the insight does not exist" do
      {_user, scope} = user_with_scope()

      assert AiRepository.get_feedback_for_insight(scope, -1) == nil
    end

    test "does not return feedback submitted by other users" do
      {_user, scope} = user_with_scope()
      account_id = Accounts.get_personal_account_id(scope)
      insight = insert_insight!(account_id)

      {other_user, _other_scope} = user_with_scope()
      insert_suggestion_feedback!(insight.id, other_user.id, %{rating: :not_helpful})

      assert AiRepository.get_feedback_for_insight(scope, insight.id) == nil
    end
  end
end
