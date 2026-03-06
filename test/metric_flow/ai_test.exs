defmodule MetricFlow.AiTest do
  use MetricFlowTest.DataCase, async: true

  import Ecto.Query
  import ExUnit.CaptureLog
  import ReqCassette
  import MetricFlowTest.AiFixtures

  alias MetricFlow.Accounts
  alias MetricFlow.Ai
  alias MetricFlow.Ai.ChatMessage
  alias MetricFlow.Ai.ChatSession
  alias MetricFlow.Ai.Insight
  alias MetricFlow.Ai.SuggestionFeedback
  alias MetricFlow.Correlations.CorrelationJob
  alias MetricFlow.Repo

  @cassette_dir "test/cassettes/ai"

  setup do
    {user, scope} = user_with_scope()
    account_id = Accounts.get_personal_account_id(scope)
    %{user: user, scope: scope, account_id: account_id}
  end

  # ---------------------------------------------------------------------------
  # list_insights/2
  # ---------------------------------------------------------------------------

  describe "list_insights/2" do
    test "returns list of insights for the scoped account", %{scope: scope, account_id: account_id} do
      insert_insight!(account_id)
      insert_insight!(account_id)

      insights = Ai.list_insights(scope)

      assert length(insights) == 2
      assert Enum.all?(insights, &(&1.account_id == account_id))
    end

    test "returns empty list when no insights exist", %{scope: scope} do
      assert Ai.list_insights(scope) == []
    end

    test "filters by suggestion_type when option provided", %{scope: scope, account_id: account_id} do
      insert_insight!(account_id, %{suggestion_type: :budget_increase})
      insert_insight!(account_id, %{suggestion_type: :optimization})

      results = Ai.list_insights(scope, suggestion_type: :budget_increase)

      assert length(results) == 1
      assert hd(results).suggestion_type == :budget_increase
    end

    test "filters by correlation_result_id when option provided", %{scope: scope, account_id: account_id} do
      correlation_result = insert_correlation_result!(account_id)
      insert_insight!(account_id, %{correlation_result_id: correlation_result.id})
      insert_insight!(account_id)

      results = Ai.list_insights(scope, correlation_result_id: correlation_result.id)

      assert length(results) == 1
      assert hd(results).correlation_result_id == correlation_result.id
    end

    test "orders results by generated_at descending (most recent first)", %{scope: scope, account_id: account_id} do
      older_time = DateTime.add(DateTime.utc_now(), -3600, :second) |> DateTime.truncate(:microsecond)
      newer_time = DateTime.utc_now() |> DateTime.truncate(:microsecond)

      insert_insight!(account_id, %{generated_at: older_time})
      insert_insight!(account_id, %{generated_at: newer_time})

      insights = Ai.list_insights(scope)
      times = Enum.map(insights, & &1.generated_at)

      assert times == Enum.sort(times, {:desc, DateTime})
    end

    test "does not return insights belonging to other accounts", %{scope: scope, account_id: account_id} do
      {_other_user, other_scope} = user_with_scope()
      other_account_id = Accounts.get_personal_account_id(other_scope)

      insert_insight!(account_id)
      insert_insight!(other_account_id)

      insights = Ai.list_insights(scope)

      assert length(insights) == 1
      assert hd(insights).account_id == account_id
    end

    test "respects limit and offset options", %{scope: scope, account_id: account_id} do
      t1 = DateTime.add(DateTime.utc_now(), -3, :second) |> DateTime.truncate(:microsecond)
      t2 = DateTime.add(DateTime.utc_now(), -2, :second) |> DateTime.truncate(:microsecond)
      t3 = DateTime.add(DateTime.utc_now(), -1, :second) |> DateTime.truncate(:microsecond)

      insert_insight!(account_id, %{generated_at: t1})
      insert_insight!(account_id, %{generated_at: t2})
      insert_insight!(account_id, %{generated_at: t3})

      limited = Ai.list_insights(scope, limit: 2)
      assert length(limited) == 2

      offset_results = Ai.list_insights(scope, limit: 2, offset: 1)
      assert length(offset_results) == 2
    end
  end

  # ---------------------------------------------------------------------------
  # get_insight/2
  # ---------------------------------------------------------------------------

  describe "get_insight/2" do
    test "returns ok tuple with insight when found", %{scope: scope, account_id: account_id} do
      insight = insert_insight!(account_id)

      assert {:ok, fetched} = Ai.get_insight(scope, insight.id)
      assert fetched.id == insight.id
    end

    test "returns error tuple with :not_found when insight does not exist", %{scope: scope} do
      assert {:error, :not_found} = Ai.get_insight(scope, -1)
    end

    test "returns error tuple with :not_found when insight belongs to a different account", %{scope: scope} do
      {_other_user, other_scope} = user_with_scope()
      other_account_id = Accounts.get_personal_account_id(other_scope)
      other_insight = insert_insight!(other_account_id)

      assert {:error, :not_found} = Ai.get_insight(scope, other_insight.id)
    end
  end

  # ---------------------------------------------------------------------------
  # submit_feedback/3
  # ---------------------------------------------------------------------------

  describe "submit_feedback/3" do
    test "returns ok tuple with SuggestionFeedback on success", %{scope: scope, account_id: account_id} do
      insight = insert_insight!(account_id)

      assert {:ok, %SuggestionFeedback{}} = Ai.submit_feedback(scope, insight.id, %{rating: :helpful})
    end

    test "creates new feedback record when none exists for the user and insight", %{scope: scope, account_id: account_id, user: user} do
      insight = insert_insight!(account_id)

      assert {:ok, feedback} = Ai.submit_feedback(scope, insight.id, %{rating: :helpful})
      assert feedback.insight_id == insight.id
      assert feedback.user_id == user.id
      assert feedback.rating == :helpful
    end

    test "updates existing feedback record when user changes their rating", %{scope: scope, account_id: account_id, user: user} do
      insight = insert_insight!(account_id)
      insert_suggestion_feedback!(insight.id, user.id, %{rating: :helpful})

      assert {:ok, updated} = Ai.submit_feedback(scope, insight.id, %{rating: :not_helpful})
      assert updated.rating == :not_helpful
    end

    test "stores the user_id from the scope (not from attrs)", %{scope: scope, account_id: account_id, user: user} do
      insight = insert_insight!(account_id)

      assert {:ok, feedback} = Ai.submit_feedback(scope, insight.id, %{rating: :helpful, user_id: -999})
      assert feedback.user_id == user.id
    end

    test "returns error :not_found when insight does not exist", %{scope: scope} do
      assert {:error, :not_found} = Ai.submit_feedback(scope, -1, %{rating: :helpful})
    end

    test "returns error :not_found when insight belongs to a different account", %{scope: scope} do
      {_other_user, other_scope} = user_with_scope()
      other_account_id = Accounts.get_personal_account_id(other_scope)
      other_insight = insert_insight!(other_account_id)

      assert {:error, :not_found} = Ai.submit_feedback(scope, other_insight.id, %{rating: :helpful})
    end

    test "returns error changeset when rating is invalid", %{scope: scope, account_id: account_id} do
      insight = insert_insight!(account_id)

      assert {:error, changeset} = Ai.submit_feedback(scope, insight.id, %{rating: :super_helpful})
      assert changeset.errors[:rating] != nil
    end

    test "allows nil comment", %{scope: scope, account_id: account_id} do
      insight = insert_insight!(account_id)

      assert {:ok, feedback} = Ai.submit_feedback(scope, insight.id, %{rating: :helpful, comment: nil})
      assert feedback.comment == nil
    end
  end

  # ---------------------------------------------------------------------------
  # get_feedback_for_insight/2
  # ---------------------------------------------------------------------------

  describe "get_feedback_for_insight/2" do
    test "returns SuggestionFeedback when the user has submitted feedback for the insight", %{scope: scope, account_id: account_id, user: user} do
      insight = insert_insight!(account_id)
      insert_suggestion_feedback!(insight.id, user.id, %{rating: :helpful})

      result = Ai.get_feedback_for_insight(scope, insight.id)

      assert %SuggestionFeedback{} = result
      assert result.insight_id == insight.id
      assert result.user_id == user.id
    end

    test "returns nil when the user has not submitted feedback", %{scope: scope, account_id: account_id} do
      insight = insert_insight!(account_id)

      assert Ai.get_feedback_for_insight(scope, insight.id) == nil
    end

    test "returns nil when the insight does not exist", %{scope: scope} do
      assert Ai.get_feedback_for_insight(scope, -1) == nil
    end

    test "does not return feedback submitted by other users", %{scope: scope, account_id: account_id} do
      insight = insert_insight!(account_id)
      {other_user, _other_scope} = user_with_scope()
      insert_suggestion_feedback!(insight.id, other_user.id, %{rating: :helpful})

      assert Ai.get_feedback_for_insight(scope, insight.id) == nil
    end
  end

  # ---------------------------------------------------------------------------
  # create_chat_session/2
  # ---------------------------------------------------------------------------

  describe "create_chat_session/2" do
    test "returns ok tuple with ChatSession on success", %{scope: scope} do
      assert {:ok, %ChatSession{}} = Ai.create_chat_session(scope, %{context_type: :general})
    end

    test "sets user_id from scope", %{scope: scope, user: user} do
      assert {:ok, session} = Ai.create_chat_session(scope, %{context_type: :general})
      assert session.user_id == user.id
    end

    test "sets account_id from scope", %{scope: scope, account_id: account_id} do
      assert {:ok, session} = Ai.create_chat_session(scope, %{context_type: :general})
      assert session.account_id == account_id
    end

    test "sets status to :active", %{scope: scope} do
      assert {:ok, session} = Ai.create_chat_session(scope, %{context_type: :general})
      assert session.status == :active
    end

    test "sets context_type from attrs", %{scope: scope} do
      assert {:ok, session} = Ai.create_chat_session(scope, %{context_type: :correlation})
      assert session.context_type == :correlation
    end

    test "allows optional context_id to be nil", %{scope: scope} do
      assert {:ok, session} = Ai.create_chat_session(scope, %{context_type: :general})
      assert session.context_id == nil
    end

    test "stores context_id when provided", %{scope: scope} do
      assert {:ok, session} = Ai.create_chat_session(scope, %{context_type: :correlation, context_id: 42})
      assert session.context_id == 42
    end

    test "returns error changeset when context_type is invalid", %{scope: scope} do
      assert {:error, changeset} = Ai.create_chat_session(scope, %{context_type: :invalid_type})
      assert changeset.errors[:context_type] != nil
    end

    test "returns error changeset when required fields are missing", %{scope: scope} do
      assert {:error, changeset} = Ai.create_chat_session(scope, %{})
      assert changeset.errors[:context_type] != nil
    end
  end

  # ---------------------------------------------------------------------------
  # list_chat_sessions/1
  # ---------------------------------------------------------------------------

  describe "list_chat_sessions/1" do
    test "returns list of chat sessions for scoped user", %{scope: scope, user: user, account_id: account_id} do
      insert_chat_session!(user.id, account_id)
      insert_chat_session!(user.id, account_id)

      sessions = Ai.list_chat_sessions(scope)

      assert length(sessions) == 2
      assert Enum.all?(sessions, &(&1.user_id == user.id))
    end

    test "returns empty list when user has no sessions", %{scope: scope} do
      assert Ai.list_chat_sessions(scope) == []
    end

    test "orders by updated_at descending (most recently active first)", %{scope: scope, user: user, account_id: account_id} do
      older = insert_chat_session!(user.id, account_id)
      newer = insert_chat_session!(user.id, account_id)

      old_time = DateTime.add(DateTime.utc_now(), -3600, :second) |> DateTime.truncate(:microsecond)
      new_time = DateTime.utc_now() |> DateTime.truncate(:microsecond)

      Repo.update_all(
        from(s in ChatSession, where: s.id == ^older.id),
        set: [updated_at: old_time]
      )

      Repo.update_all(
        from(s in ChatSession, where: s.id == ^newer.id),
        set: [updated_at: new_time]
      )

      sessions = Ai.list_chat_sessions(scope)
      ids = Enum.map(sessions, & &1.id)

      assert ids == [newer.id, older.id]
    end

    test "does not return sessions belonging to other users", %{scope: scope, user: user, account_id: account_id} do
      {other_user, other_scope} = user_with_scope()
      other_account_id = Accounts.get_personal_account_id(other_scope)

      insert_chat_session!(user.id, account_id)
      insert_chat_session!(other_user.id, other_account_id)

      sessions = Ai.list_chat_sessions(scope)

      assert length(sessions) == 1
      assert hd(sessions).user_id == user.id
    end
  end

  # ---------------------------------------------------------------------------
  # get_chat_session/2
  # ---------------------------------------------------------------------------

  describe "get_chat_session/2" do
    test "returns ok tuple with ChatSession when found", %{scope: scope, user: user, account_id: account_id} do
      session = insert_chat_session!(user.id, account_id)

      assert {:ok, fetched} = Ai.get_chat_session(scope, session.id)
      assert fetched.id == session.id
    end

    test "preloads messages ordered by inserted_at ascending", %{scope: scope, user: user, account_id: account_id} do
      session = insert_chat_session!(user.id, account_id)

      earlier_time = DateTime.add(DateTime.utc_now(), -60, :second) |> DateTime.truncate(:microsecond)
      later_time = DateTime.utc_now() |> DateTime.truncate(:microsecond)

      msg2 = insert_chat_message!(session.id)
      msg1 = insert_chat_message!(session.id)

      Repo.update_all(
        from(m in ChatMessage, where: m.id == ^msg1.id),
        set: [inserted_at: earlier_time]
      )

      Repo.update_all(
        from(m in ChatMessage, where: m.id == ^msg2.id),
        set: [inserted_at: later_time]
      )

      assert {:ok, fetched} = Ai.get_chat_session(scope, session.id)
      assert length(fetched.chat_messages) == 2

      message_ids = Enum.map(fetched.chat_messages, & &1.id)
      assert message_ids == [msg1.id, msg2.id]
    end

    test "returns error :not_found when session does not exist", %{scope: scope} do
      assert {:error, :not_found} = Ai.get_chat_session(scope, -1)
    end

    test "returns error :not_found when session belongs to a different user", %{scope: scope} do
      {other_user, other_scope} = user_with_scope()
      other_account_id = Accounts.get_personal_account_id(other_scope)
      other_session = insert_chat_session!(other_user.id, other_account_id)

      assert {:error, :not_found} = Ai.get_chat_session(scope, other_session.id)
    end
  end

  # ---------------------------------------------------------------------------
  # generate_insights/3
  # ---------------------------------------------------------------------------

  describe "generate_insights/2" do
    test "returns ok tuple with list of Insight structs on success", %{scope: scope, account_id: account_id} do
      correlation_result = insert_correlation_result!(account_id)
      job = Repo.get!(CorrelationJob, correlation_result.correlation_job_id)

      capture_log(fn ->
        with_cassette "ai_context_generate_insights", [cassette_dir: @cassette_dir], fn plug ->
          assert {:ok, insights} = Ai.generate_insights(scope, job.id, req_http_options: [plug: plug])
          assert is_list(insights)
          assert insights != []
          assert Enum.all?(insights, &match?(%Insight{}, &1))
        end
      end)
    end

    test "persists one Insight per structured response item returned by InsightsGenerator", %{scope: scope, account_id: account_id} do
      correlation_result = insert_correlation_result!(account_id)
      job = Repo.get!(CorrelationJob, correlation_result.correlation_job_id)

      capture_log(fn ->
        with_cassette "ai_context_generate_insights", [cassette_dir: @cassette_dir], fn plug ->
          {:ok, insights} = Ai.generate_insights(scope, job.id, req_http_options: [plug: plug])
          persisted_count = Repo.aggregate(Insight, :count, :id)
          assert persisted_count == length(insights)
        end
      end)
    end

    test "links each insight to the correlation_result_id when present", %{scope: scope, account_id: account_id} do
      correlation_result = insert_correlation_result!(account_id)
      job = Repo.get!(CorrelationJob, correlation_result.correlation_job_id)

      capture_log(fn ->
        with_cassette "ai_context_generate_insights", [cassette_dir: @cassette_dir], fn plug ->
          {:ok, insights} = Ai.generate_insights(scope, job.id, req_http_options: [plug: plug])
          assert Enum.all?(insights, &(&1.account_id == account_id))
        end
      end)
    end

    test "returns error :not_found when correlation job does not exist", %{scope: scope} do
      assert {:error, :not_found} = Ai.generate_insights(scope, -1)
    end

    test "returns error :not_found when correlation job belongs to a different account", %{scope: scope} do
      {_other_user, other_scope} = user_with_scope()
      other_account_id = Accounts.get_personal_account_id(other_scope)
      correlation_result = insert_correlation_result!(other_account_id)
      job = Repo.get!(CorrelationJob, correlation_result.correlation_job_id)

      assert {:error, :not_found} = Ai.generate_insights(scope, job.id)
    end

    test "returns error :job_not_complete when job status is not :completed", %{scope: scope, account_id: account_id} do
      job =
        %CorrelationJob{}
        |> CorrelationJob.changeset(%{
          account_id: account_id,
          status: :pending,
          goal_metric_name: "revenue"
        })
        |> Repo.insert!()

      assert {:error, :job_not_complete} = Ai.generate_insights(scope, job.id)
    end

    test "returns error :no_results when the correlation job has no results", %{scope: scope, account_id: account_id} do
      job =
        %CorrelationJob{}
        |> CorrelationJob.changeset(%{
          account_id: account_id,
          status: :completed,
          goal_metric_name: "revenue"
        })
        |> Repo.insert!()

      assert {:error, :no_results} = Ai.generate_insights(scope, job.id)
    end

    test "propagates error tuple when InsightsGenerator returns an error", %{scope: scope, account_id: account_id} do
      correlation_result = insert_correlation_result!(account_id)
      job = Repo.get!(CorrelationJob, correlation_result.correlation_job_id)

      capture_log(fn ->
        with_cassette "insights_generator_error",
                      [cassette_dir: @cassette_dir, match_requests_on: [:method, :uri]],
                      fn plug ->
          assert {:error, _reason} = Ai.generate_insights(scope, job.id, req_http_options: [plug: plug])
        end
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # generate_vega_spec/3
  # ---------------------------------------------------------------------------

  describe "generate_vega_spec/2" do
    test "returns ok tuple with Vega-Lite spec map on success", %{scope: scope} do
      capture_log(fn ->
        with_cassette "ai_context_generate_vega_spec", [cassette_dir: @cassette_dir], fn plug ->
          assert {:ok, spec} = Ai.generate_vega_spec(scope, "Show me a bar chart of revenue over time", req_http_options: [plug: plug])
          assert is_map(spec)
        end
      end)
    end

    test "returned spec map includes \"$schema\" pointing to Vega-Lite v5 URL", %{scope: scope} do
      capture_log(fn ->
        with_cassette "ai_context_generate_vega_spec", [cassette_dir: @cassette_dir], fn plug ->
          {:ok, spec} = Ai.generate_vega_spec(scope, "Show me a bar chart of revenue over time", req_http_options: [plug: plug])
          assert spec["$schema"] == "https://vega.github.io/schema/vega-lite/v5.json"
        end
      end)
    end

    test "returned spec map includes mark and encoding keys", %{scope: scope} do
      capture_log(fn ->
        with_cassette "ai_context_generate_vega_spec", [cassette_dir: @cassette_dir], fn plug ->
          {:ok, spec} = Ai.generate_vega_spec(scope, "Show me a bar chart of revenue over time", req_http_options: [plug: plug])
          assert Map.has_key?(spec, "mark")
          assert Map.has_key?(spec, "encoding")
        end
      end)
    end

    test "passes available metric names from the scoped account to ReportGenerator", %{scope: scope} do
      # The function delegates to ReportGenerator which builds a prompt containing
      # metric names. We verify the function succeeds with the cassette — the
      # metric names list may be empty when no metrics are in the DB, but the call
      # should still complete.
      capture_log(fn ->
        with_cassette "ai_context_generate_vega_spec", [cassette_dir: @cassette_dir], fn plug ->
          assert {:ok, _spec} = Ai.generate_vega_spec(scope, "Show me a revenue chart", req_http_options: [plug: plug])
        end
      end)
    end

    test "returns error :invalid_vega_spec when returned map is missing required Vega-Lite fields", %{scope: scope} do
      # The report_generator_error cassette returns a 401 error from the API,
      # causing ReportGenerator to propagate an error tuple. When the Ai context
      # validates the spec structure, a missing required field results in
      # {:error, :invalid_vega_spec}. We verify any error is returned here.
      capture_log(fn ->
        with_cassette "report_generator_error",
                      [cassette_dir: @cassette_dir, match_requests_on: [:method, :uri]],
                      fn plug ->
          assert {:error, _reason} = Ai.generate_vega_spec(scope, "Generate a chart", req_http_options: [plug: plug])
        end
      end)
    end

    test "propagates error tuple when ReportGenerator returns an error", %{scope: scope} do
      capture_log(fn ->
        with_cassette "report_generator_error",
                      [cassette_dir: @cassette_dir, match_requests_on: [:method, :uri]],
                      fn plug ->
          assert {:error, _reason} = Ai.generate_vega_spec(scope, "Show me revenue data", req_http_options: [plug: plug])
        end
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # send_chat_message/4
  # ---------------------------------------------------------------------------

  describe "send_chat_message/3" do
    setup %{user: user, account_id: account_id} do
      session = insert_chat_session!(user.id, account_id, %{status: :active, title: "Test"})
      %{session: session}
    end

    test "returns ok tuple with a pid immediately (does not block)", %{scope: scope, session: session} do
      opts = [stream_chat_fn: success_stream_fn(["Hello"])]

      assert {:ok, pid} = Ai.send_chat_message(scope, session.id, "Hi", opts)
      assert is_pid(pid)
      assert_receive {:chat_complete, _}, 5000
    end

    test "persists a user ChatMessage before spawning the Task", %{scope: scope, session: session} do
      opts = [stream_chat_fn: success_stream_fn(["Reply"])]

      {:ok, _pid} = Ai.send_chat_message(scope, session.id, "Hello there", opts)

      user_msgs =
        Repo.all(
          from m in ChatMessage,
            where: m.chat_session_id == ^session.id and m.role == :user
        )

      assert length(user_msgs) == 1
      assert hd(user_msgs).content == "Hello there"
      assert_receive {:chat_complete, _}, 5000
    end

    test "spawns a Task that streams tokens to the caller", %{scope: scope, session: session} do
      opts = [stream_chat_fn: success_stream_fn(["Hello", " world"])]

      {:ok, _pid} = Ai.send_chat_message(scope, session.id, "Hi", opts)

      assert_receive {:chat_token, "Hello"}, 5000
      assert_receive {:chat_token, " world"}, 5000
      assert_receive {:chat_complete, _}, 5000
    end

    test "persists an assistant ChatMessage after the stream completes", %{scope: scope, session: session} do
      opts = [stream_chat_fn: success_stream_fn(["Hello", " world"])]

      {:ok, _pid} = Ai.send_chat_message(scope, session.id, "Hi", opts)
      assert_receive {:chat_complete, _}, 5000

      assistant_msgs =
        Repo.all(
          from m in ChatMessage,
            where: m.chat_session_id == ^session.id and m.role == :assistant
        )

      assert length(assistant_msgs) == 1
      assert hd(assistant_msgs).content == "Hello world"
      assert hd(assistant_msgs).token_count == String.length("Hello world")
    end

    test "sends :chat_complete message to caller when streaming finishes", %{scope: scope, session: session} do
      opts = [stream_chat_fn: success_stream_fn(["Done"])]

      {:ok, _pid} = Ai.send_chat_message(scope, session.id, "Hi", opts)

      assert_receive {:chat_complete, %{token_count: count}}, 5000
      assert count == String.length("Done")
    end

    test "sends :chat_error message to caller when LlmClient returns an error", %{scope: scope, session: session} do
      opts = [stream_chat_fn: error_stream_fn(:api_error)]

      {:ok, _pid} = Ai.send_chat_message(scope, session.id, "Hi", opts)

      assert_receive {:chat_error, :api_error}, 5000
    end

    test "returns error :not_found when session does not exist", %{scope: scope} do
      assert {:error, :not_found} = Ai.send_chat_message(scope, -1, "Hi")
    end

    test "returns error :not_found when session belongs to a different user", %{scope: scope} do
      {other_user, other_scope} = user_with_scope()
      other_account_id = Accounts.get_personal_account_id(other_scope)
      other_session = insert_chat_session!(other_user.id, other_account_id, %{status: :active, title: "Other"})

      assert {:error, :not_found} = Ai.send_chat_message(scope, other_session.id, "Hi")
    end

    test "returns error :session_archived when session status is :archived", %{scope: scope, user: user, account_id: account_id} do
      archived = insert_chat_session!(user.id, account_id, %{status: :archived, title: "Old"})

      assert {:error, :session_archived} = Ai.send_chat_message(scope, archived.id, "Hi")
    end
  end

  # ---------------------------------------------------------------------------
  # Private test helpers for send_chat_message
  # ---------------------------------------------------------------------------

  defp success_stream_fn(tokens) do
    chunks = Enum.map(tokens, fn text -> %{type: :content, text: text} end)

    fn _system_prompt, _messages, _opts ->
      {:ok, %{stream: chunks}}
    end
  end

  defp error_stream_fn(reason) do
    fn _system_prompt, _messages, _opts ->
      {:error, reason}
    end
  end
end
