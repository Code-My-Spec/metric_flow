defmodule MetricFlowWeb.AiLive.ChatTest do
  use MetricFlowTest.ConnCase, async: false

  import ExUnit.CaptureLog
  import Phoenix.LiveViewTest
  import MetricFlowTest.AiFixtures
  import MetricFlowTest.BillingFixtures

  alias MetricFlow.Accounts

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp user_with_account do
    {user, scope} = user_with_scope()
    account_id = Accounts.get_personal_account_id(scope)
    # Every screen these tests mount sits behind `RequireSubscriptionHook`, which
    # redirects to checkout without one.
    active_subscription_fixture(account_id)
    {user, account_id, scope}
  end

  defp mount_chat(conn, user) do
    conn = log_in_user(conn, user)
    live(conn, ~p"/app/chat")
  end

  defp mount_chat_session(conn, user, session_id) do
    conn = log_in_user(conn, user)
    live(conn, ~p"/app/chat/#{session_id}")
  end

  # ---------------------------------------------------------------------------
  # Test Assertions from spec
  # ---------------------------------------------------------------------------

  describe "renders chat page with session sidebar and conversation area" do
    test "renders chat page with session sidebar and conversation area", %{conn: conn} do
      {user, _account_id, _scope} = user_with_account()

      capture_log(fn ->
        {:ok, lv, html} = mount_chat(conn, user)

        assert html =~ "AI Chat"
        assert has_element?(lv, "[data-role='session-sidebar']")
        assert has_element?(lv, "[data-role='conversation-area']")
        assert has_element?(lv, "[data-role='message-input-area']")
        assert has_element?(lv, "[data-role='message-input']")
        assert has_element?(lv, "[data-role='send-btn']")
        assert has_element?(lv, "[data-role='new-chat-btn']")
      end)
    end
  end

  describe "shows empty state with example prompts when no sessions exist" do
    test "shows empty state with example prompts when no sessions exist", %{conn: conn} do
      {user, _account_id, _scope} = user_with_account()

      capture_log(fn ->
        {:ok, lv, html} = mount_chat(conn, user)

        assert has_element?(lv, "[data-role='chat-empty-state']")
        assert html =~ "What can I help you with today?"
        assert has_element?(lv, "[data-role='example-prompt']")
        assert has_element?(lv, "[data-role='no-sessions-state']")
      end)
    end
  end

  describe "renders the Anderson BI mockup hero on the empty state" do
    test "shows the four suggestion cards and the composer placeholder", %{conn: conn} do
      {user, _account_id, _scope} = user_with_account()

      capture_log(fn ->
        {:ok, lv, html} = mount_chat(conn, user)

        assert html =~ "What can I help you with today?"
        assert html =~ "Business Performance"
        assert html =~ "Customer Insights"
        assert html =~ "Marketing Effectiveness"
        assert html =~ "Financial Health"

        assert html =~ "business performance this quarter"

        assert has_element?(
                 lv,
                 "textarea[data-role='message-input'][placeholder='Ask about revenue, marketing, customer trends, cash flow, or anything else...']"
               )
      end)
    end
  end

  describe "shows the AI greeting when sessions exist but none is active" do
    test "shows the AI greeting when sessions exist but none is active", %{conn: conn} do
      {user, account_id, _scope} = user_with_account()
      insert_chat_session!(user.id, account_id)

      capture_log(fn ->
        {:ok, lv, html} = mount_chat(conn, user)

        assert has_element?(lv, "[data-role='chat-empty-state']")
        assert html =~ "What can I help you with today?"
        assert has_element?(lv, "[data-role='session-item']")
      end)
    end
  end

  describe "clicking an empty-state example prompt sends it as a message" do
    test "clicking an empty-state example prompt sends it as a message", %{conn: conn} do
      {user, _account_id, _scope} = user_with_account()

      capture_log(fn ->
        {:ok, lv, _html} = mount_chat(conn, user)

        lv
        |> element("[data-role='example-prompt']", "business performance this quarter")
        |> render_click()

        assert has_element?(
                 lv,
                 "[data-role='user-message']",
                 "business performance this quarter"
               )

        refute has_element?(lv, "[data-role='chat-empty-state']")
      end)
    end
  end

  describe "clicking an example prompt without a resolvable account shows an error instead of sending" do
    test "clicking an example prompt without a resolvable account shows an error instead of sending",
         %{conn: conn} do
      user = MetricFlowTest.UsersFixtures.user_fixture()

      capture_log(fn ->
        {:ok, lv, _html} = mount_chat(conn, user)

        lv
        |> element("[data-role='example-prompt']", "business performance this quarter")
        |> render_click()

        assert render(lv) =~ "Could not start chat session."
        refute has_element?(lv, "[data-role='user-message']")
      end)
    end
  end

  describe "creates a new session and displays it when a message is sent" do
    test "creates a new session and displays it when a message is sent", %{conn: conn} do
      {user, _account_id, _scope} = user_with_account()

      capture_log(fn ->
        {:ok, lv, _html} = mount_chat(conn, user)

        render_change(lv, "update_input", %{"content" => "What is my revenue trend?"})
        render_submit(lv, "send_message", %{"content" => "What is my revenue trend?"})

        assert has_element?(lv, "[data-role='message']")
      end)
    end
  end

  describe "loads an existing session and displays its messages" do
    test "loads an existing session and displays its messages", %{conn: conn} do
      {user, account_id, _scope} = user_with_account()
      session = insert_chat_session!(user.id, account_id, %{title: "Revenue Chat"})
      insert_chat_message!(session.id, %{role: :user, content: "Show revenue"})
      insert_chat_message!(session.id, %{role: :assistant, content: "Here is your revenue data."})

      capture_log(fn ->
        {:ok, lv, html} = mount_chat_session(conn, user, session.id)

        assert has_element?(lv, "[data-role='message-list']")
        assert html =~ "Show revenue"
        assert html =~ "Here is your revenue data."
        assert has_element?(lv, "[data-role='session-header']")
      end)
    end
  end

  describe "active conversation exposes its session id for the share-insight spex" do
    test "the message list carries data-session-id matching the active session", %{conn: conn} do
      {user, account_id, _scope} = user_with_account()
      session = insert_chat_session!(user.id, account_id)
      insert_chat_message!(session.id, %{role: :assistant, content: "ok"})

      capture_log(fn ->
        {:ok, _lv, html} = mount_chat_session(conn, user, session.id)

        assert [_, matched_id] = Regex.run(~r/data-session-id="(\d+)"/, html)
        assert matched_id == to_string(session.id)
      end)
    end
  end

  describe "streams assistant response tokens into the conversation" do
    test "streams assistant response tokens into the conversation", %{conn: conn} do
      {user, account_id, _scope} = user_with_account()
      session = insert_chat_session!(user.id, account_id)
      insert_chat_message!(session.id, %{role: :user, content: "test"})

      capture_log(fn ->
        {:ok, lv, _html} = mount_chat_session(conn, user, session.id)

        # Send chat_complete to verify it doesn't crash
        send(lv.pid, {:chat_complete, %{token_count: 10}})
        html = render(lv)
        assert is_binary(html)
        assert has_element?(lv, "[data-role='message-list']")
      end)
    end
  end

  describe "shows streaming indicator while waiting for response" do
    test "shows streaming indicator while waiting for response", %{conn: conn} do
      {user, account_id, _scope} = user_with_account()
      session = insert_chat_session!(user.id, account_id)

      capture_log(fn ->
        {:ok, lv, _html} = mount_chat_session(conn, user, session.id)

        render_change(lv, "update_input", %{"content" => "test"})
        render_submit(lv, "send_message", %{"content" => "test"})

        # The streaming state should be set
        html = render(lv)
        assert html =~ "streaming" or has_element?(lv, "[data-role='streaming-waiting']")
      end)
    end
  end

  describe "updates input value on change and disables send when blank" do
    test "updates input value on change and disables send when blank", %{conn: conn} do
      {user, _account_id, _scope} = user_with_account()

      capture_log(fn ->
        {:ok, lv, _html} = mount_chat(conn, user)

        # Send button should be disabled with blank input
        assert has_element?(lv, "[data-role='send-btn'][disabled]")

        render_change(lv, "update_input", %{"content" => "Hello"})

        refute has_element?(lv, "[data-role='send-btn'][disabled]")
      end)
    end
  end

  describe "navigates to a session when sidebar item is clicked" do
    test "navigates to a session when sidebar item is clicked", %{conn: conn} do
      {user, account_id, _scope} = user_with_account()
      session = insert_chat_session!(user.id, account_id, %{title: "My Chat"})
      insert_chat_message!(session.id, %{role: :user, content: "Hello"})

      capture_log(fn ->
        {:ok, lv, _html} = mount_chat(conn, user)

        render_click(lv, "select_session", %{"id" => to_string(session.id)})

        assert has_element?(lv, "[data-role='message-list']")
      end)
    end
  end

  describe "starts a new chat when new chat button is clicked" do
    test "starts a new chat when new chat button is clicked", %{conn: conn} do
      {user, account_id, _scope} = user_with_account()
      session = insert_chat_session!(user.id, account_id)

      capture_log(fn ->
        {:ok, lv, _html} = mount_chat_session(conn, user, session.id)

        lv |> element("[data-role='new-chat-btn']") |> render_click()

        assert has_element?(lv, "[data-role='new-chat-header']")
        refute has_element?(lv, "[data-role='message-list']")
      end)
    end
  end

  describe "shows error flash when loading a non-existent session ID" do
    test "shows error flash when loading a non-existent session ID", %{conn: conn} do
      {user, _account_id, _scope} = user_with_account()

      capture_log(fn ->
        conn = log_in_user(conn, user)

        assert {:error,
                {:live_redirect,
                 %{to: "/app/chat", flash: %{"error" => "Chat session not found."}}}} =
                 live(conn, ~p"/app/chat/999999")
      end)
    end
  end

  describe "shows context indicator when context_type query param is set" do
    test "shows context indicator when context_type query param is set", %{conn: conn} do
      {user, _account_id, _scope} = user_with_account()

      capture_log(fn ->
        conn = log_in_user(conn, user)
        {:ok, lv, _html} = live(conn, ~p"/app/chat?context_type=correlation")

        assert has_element?(lv, "[data-role='context-indicator']")
      end)
    end
  end

  describe "renders inline error with Retry when the AI call fails" do
    # P0 regression (chat-responds-p0): the main chat used to flash a generic
    # "AI encountered an error" toast on failure, and the Correlations
    # contextual chat (same LV, context_type=correlation) hung silently when
    # the stream task raised. The fix keeps the user in the conversation with
    # an inline error + Retry, and makes the task tolerant of crashes.
    test "chat_error renders inline, replaces the toast, and Retry resends the prompt",
         %{conn: conn} do
      {user, account_id, _scope} = user_with_account()
      session = insert_chat_session!(user.id, account_id)

      test_pid = self()

      {:ok, agent} =
        Agent.start_link(fn ->
          [
            fn _sys, _msgs, _on_chunk, _opts ->
              send(test_pid, :first_called)
              {:error, :api_error}
            end,
            fn _sys, _msgs, on_chunk, _opts ->
              on_chunk.("retry worked")
              send(test_pid, :second_called)
              {:ok, "retry worked"}
            end
          ]
        end)

      stream_fn = fn sys, msgs, on_chunk, opts ->
        fun = Agent.get_and_update(agent, fn [h | t] -> {h, t} end)
        fun.(sys, msgs, on_chunk, opts)
      end

      Application.put_env(:metric_flow, :test_llm_options, stream_chat_fn: stream_fn)
      on_exit(fn -> Application.delete_env(:metric_flow, :test_llm_options) end)

      capture_log(fn ->
        {:ok, lv, _html} = mount_chat_session(conn, user, session.id)

        render_change(lv, "update_input", %{"content" => "How did we do this month?"})
        render_submit(lv, "send_message", %{"content" => "How did we do this month?"})

        assert_receive :first_called, 2_000
        # Flush the LV's mailbox so the :chat_error handle_info has run
        # before we inspect the DOM.
        _ = :sys.get_state(lv.pid)

        html = render(lv)
        assert has_element?(lv, "[data-role='chat-error']")
        assert has_element?(lv, "[data-role='retry-btn']")
        refute html =~ "AI encountered an error"

        lv |> element("[data-role='retry-btn']") |> render_click()

        assert_receive :second_called, 2_000
      end)
    end

    test "a crash in the stream task does not hang: inline error still surfaces",
         %{conn: conn} do
      {user, account_id, _scope} = user_with_account()
      session = insert_chat_session!(user.id, account_id)

      test_pid = self()

      crashing_stream_fn = fn _sys, _msgs, _on_chunk, _opts ->
        send(test_pid, :crashing_called)
        raise "provider wedged"
      end

      Application.put_env(:metric_flow, :test_llm_options, stream_chat_fn: crashing_stream_fn)
      on_exit(fn -> Application.delete_env(:metric_flow, :test_llm_options) end)

      capture_log(fn ->
        {:ok, lv, _html} = mount_chat_session(conn, user, session.id)

        render_change(lv, "update_input", %{"content" => "Are there any correlations to revenue?"})

        render_submit(lv, "send_message", %{
          "content" => "Are there any correlations to revenue?"
        })

        assert_receive :crashing_called, 2_000
        _ = :sys.get_state(lv.pid)

        assert has_element?(lv, "[data-role='chat-error']")
        assert has_element?(lv, "[data-role='retry-btn']")
      end)
    end
  end
end
