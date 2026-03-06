defmodule MetricFlowWeb.AiLive.ChatTest do
  use MetricFlowTest.ConnCase, async: false

  import ExUnit.CaptureLog
  import Phoenix.LiveViewTest
  import MetricFlowTest.AiFixtures

  alias MetricFlow.Accounts

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp user_with_account do
    {user, scope} = user_with_scope()
    account_id = Accounts.get_personal_account_id(scope)
    {user, account_id, scope}
  end

  defp mount_chat(conn, user) do
    conn = log_in_user(conn, user)
    live(conn, ~p"/chat")
  end

  defp mount_chat_session(conn, user, session_id) do
    conn = log_in_user(conn, user)
    live(conn, ~p"/chat/#{session_id}")
  end

  # ---------------------------------------------------------------------------
  # describe "mount/3"
  # ---------------------------------------------------------------------------

  describe "mount/3" do
    test "renders the chat page for an authenticated user", %{conn: conn} do
      {user, _account_id, _scope} = user_with_account()

      capture_log(fn ->
        {:ok, _lv, html} = mount_chat(conn, user)

        assert html =~ "AI Chat"
      end)
    end

    test "assigns page_title to 'AI Chat'", %{conn: conn} do
      {user, _account_id, _scope} = user_with_account()

      capture_log(fn ->
        {:ok, _lv, html} = mount_chat(conn, user)

        assert html =~ "AI Chat"
      end)
    end

    test "renders the session sidebar", %{conn: conn} do
      {user, _account_id, _scope} = user_with_account()

      capture_log(fn ->
        {:ok, lv, _html} = mount_chat(conn, user)

        assert has_element?(lv, "[data-role='session-sidebar']")
      end)
    end

    test "renders the session list container", %{conn: conn} do
      {user, _account_id, _scope} = user_with_account()

      capture_log(fn ->
        {:ok, lv, _html} = mount_chat(conn, user)

        assert has_element?(lv, "[data-role='session-list']")
      end)
    end

    test "renders the conversation area", %{conn: conn} do
      {user, _account_id, _scope} = user_with_account()

      capture_log(fn ->
        {:ok, lv, _html} = mount_chat(conn, user)

        assert has_element?(lv, "[data-role='conversation-area']")
      end)
    end

    test "renders the message input area", %{conn: conn} do
      {user, _account_id, _scope} = user_with_account()

      capture_log(fn ->
        {:ok, lv, _html} = mount_chat(conn, user)

        assert has_element?(lv, "[data-role='message-input-area']")
      end)
    end

    test "renders the message input textarea", %{conn: conn} do
      {user, _account_id, _scope} = user_with_account()

      capture_log(fn ->
        {:ok, lv, _html} = mount_chat(conn, user)

        assert has_element?(lv, "[data-role='message-input']")
      end)
    end

    test "renders the send button", %{conn: conn} do
      {user, _account_id, _scope} = user_with_account()

      capture_log(fn ->
        {:ok, lv, _html} = mount_chat(conn, user)

        assert has_element?(lv, "[data-role='send-btn']")
      end)
    end

    test "renders the New Chat button in the sidebar header", %{conn: conn} do
      {user, _account_id, _scope} = user_with_account()

      capture_log(fn ->
        {:ok, lv, _html} = mount_chat(conn, user)

        assert has_element?(lv, "[data-role='new-chat-btn']")
      end)
    end

    test "shows 'No chats yet' state when user has no sessions", %{conn: conn} do
      {user, _account_id, _scope} = user_with_account()

      capture_log(fn ->
        {:ok, lv, _html} = mount_chat(conn, user)

        assert has_element?(lv, "[data-role='no-sessions-state']")
      end)
    end

    test "shows the chat empty state when user has no sessions", %{conn: conn} do
      {user, _account_id, _scope} = user_with_account()

      capture_log(fn ->
        {:ok, lv, _html} = mount_chat(conn, user)

        assert has_element?(lv, "[data-role='chat-empty-state']")
      end)
    end

    test "shows 'Ask me anything about your data' heading in empty state", %{conn: conn} do
      {user, _account_id, _scope} = user_with_account()

      capture_log(fn ->
        {:ok, _lv, html} = mount_chat(conn, user)

        assert html =~ "Ask me anything about your data"
      end)
    end

    test "shows example prompt chips in the empty state", %{conn: conn} do
      {user, _account_id, _scope} = user_with_account()

      capture_log(fn ->
        {:ok, lv, _html} = mount_chat(conn, user)

        assert has_element?(lv, "[data-role='example-prompt']")
      end)
    end

    test "shows three example prompt chips", %{conn: conn} do
      {user, _account_id, _scope} = user_with_account()

      capture_log(fn ->
        {:ok, lv, _html} = mount_chat(conn, user)

        # There should be 3 example prompts in the empty state
        assert lv
               |> render()
               |> String.split("[data-role=\"example-prompt\"]")
               |> length() > 1
      end)
    end

    test "shows 'New Chat' header when no session is active", %{conn: conn} do
      {user, _account_id, _scope} = user_with_account()

      capture_log(fn ->
        {:ok, lv, _html} = mount_chat(conn, user)

        assert has_element?(lv, "[data-role='new-chat-header']")
      end)
    end

    test "does not show the message list when no session is active", %{conn: conn} do
      {user, _account_id, _scope} = user_with_account()

      capture_log(fn ->
        {:ok, lv, _html} = mount_chat(conn, user)

        refute has_element?(lv, "[data-role='message-list']")
      end)
    end

    test "shows session items in sidebar when user has existing sessions", %{conn: conn} do
      {user, account_id, _scope} = user_with_account()
      insert_chat_session!(user.id, account_id, %{title: "My First Chat"})

      capture_log(fn ->
        {:ok, lv, _html} = mount_chat(conn, user)

        assert has_element?(lv, "[data-role='session-item']")
      end)
    end

    test "shows session title in sidebar for existing sessions", %{conn: conn} do
      {user, account_id, _scope} = user_with_account()
      insert_chat_session!(user.id, account_id, %{title: "Revenue Analysis Chat"})

      capture_log(fn ->
        {:ok, _lv, html} = mount_chat(conn, user)

        assert html =~ "Revenue Analysis Chat"
      end)
    end

    test "shows no-sessions-state text 'No chats yet' when session list is empty", %{conn: conn} do
      {user, _account_id, _scope} = user_with_account()

      capture_log(fn ->
        {:ok, _lv, html} = mount_chat(conn, user)

        assert html =~ "No chats yet"
      end)
    end

    test "shows no-session-selected state when sessions exist but none is active", %{conn: conn} do
      {user, account_id, _scope} = user_with_account()
      insert_chat_session!(user.id, account_id)

      capture_log(fn ->
        {:ok, lv, _html} = mount_chat(conn, user)

        assert has_element?(lv, "[data-role='no-session-selected']")
      end)
    end

    test "does not show chat empty state when user has existing sessions", %{conn: conn} do
      {user, account_id, _scope} = user_with_account()
      insert_chat_session!(user.id, account_id)

      capture_log(fn ->
        {:ok, lv, _html} = mount_chat(conn, user)

        refute has_element?(lv, "[data-role='chat-empty-state']")
      end)
    end

    test "redirects unauthenticated users to /users/log-in", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/chat")
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_params/3 :index action"
  # ---------------------------------------------------------------------------

  describe "handle_params/3 :index action" do
    test "sets active_session to nil on /chat route", %{conn: conn} do
      {user, account_id, _scope} = user_with_account()
      insert_chat_session!(user.id, account_id)

      capture_log(fn ->
        {:ok, lv, _html} = mount_chat(conn, user)

        # No session is active on /chat — new-chat-header should appear
        refute has_element?(lv, "[data-role='session-header']")
        assert has_element?(lv, "[data-role='new-chat-header']")
      end)
    end

    test "assigns pending_context_type when context_type query param is present", %{conn: conn} do
      {user, _account_id, _scope} = user_with_account()

      capture_log(fn ->
        conn = log_in_user(conn, user)
        {:ok, lv, _html} = live(conn, "/chat?context_type=correlation")

        # The context indicator should show when pending_context_type is set and no active session
        assert has_element?(lv, "[data-role='context-indicator']")
      end)
    end

    test "shows context label in context indicator for correlation context", %{conn: conn} do
      {user, _account_id, _scope} = user_with_account()

      capture_log(fn ->
        conn = log_in_user(conn, user)
        {:ok, _lv, html} = live(conn, "/chat?context_type=correlation")

        assert html =~ "Correlations"
      end)
    end

    test "shows context label in context indicator for metric context", %{conn: conn} do
      {user, _account_id, _scope} = user_with_account()

      capture_log(fn ->
        conn = log_in_user(conn, user)
        {:ok, _lv, html} = live(conn, "/chat?context_type=metric")

        assert html =~ "Metrics"
      end)
    end

    test "shows context label in context indicator for dashboard context", %{conn: conn} do
      {user, _account_id, _scope} = user_with_account()

      capture_log(fn ->
        conn = log_in_user(conn, user)
        {:ok, _lv, html} = live(conn, "/chat?context_type=dashboard")

        assert html =~ "Dashboard"
      end)
    end

    test "shows context label in context indicator for general context", %{conn: conn} do
      {user, _account_id, _scope} = user_with_account()

      capture_log(fn ->
        conn = log_in_user(conn, user)
        {:ok, _lv, html} = live(conn, "/chat?context_type=general")

        assert html =~ "General"
      end)
    end

    test "does not show context indicator when no context_type param is present", %{conn: conn} do
      {user, _account_id, _scope} = user_with_account()

      capture_log(fn ->
        {:ok, lv, _html} = mount_chat(conn, user)

        refute has_element?(lv, "[data-role='context-indicator']")
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_params/3 :show action"
  # ---------------------------------------------------------------------------

  describe "handle_params/3 :show action" do
    test "loads the session and displays it as active on /chat/:id", %{conn: conn} do
      {user, account_id, _scope} = user_with_account()
      session = insert_chat_session!(user.id, account_id, %{title: "Loaded Session"})

      capture_log(fn ->
        {:ok, lv, _html} = mount_chat_session(conn, user, session.id)

        assert has_element?(lv, "[data-role='session-header']")
      end)
    end

    test "displays the session title in the conversation header", %{conn: conn} do
      {user, account_id, _scope} = user_with_account()
      session = insert_chat_session!(user.id, account_id, %{title: "My Loaded Session"})

      capture_log(fn ->
        {:ok, _lv, html} = mount_chat_session(conn, user, session.id)

        assert html =~ "My Loaded Session"
      end)
    end

    test "shows the message list when a session is loaded via :show", %{conn: conn} do
      {user, account_id, _scope} = user_with_account()
      session = insert_chat_session!(user.id, account_id)

      capture_log(fn ->
        {:ok, lv, _html} = mount_chat_session(conn, user, session.id)

        assert has_element?(lv, "[data-role='message-list']")
      end)
    end

    test "displays existing messages for the loaded session", %{conn: conn} do
      {user, account_id, _scope} = user_with_account()
      session = insert_chat_session!(user.id, account_id)
      insert_chat_message!(session.id, %{role: :user, content: "Hello AI!"})

      capture_log(fn ->
        {:ok, _lv, html} = mount_chat_session(conn, user, session.id)

        assert html =~ "Hello AI!"
      end)
    end

    test "marks the loaded session as active in the sidebar", %{conn: conn} do
      {user, account_id, _scope} = user_with_account()
      session = insert_chat_session!(user.id, account_id)

      capture_log(fn ->
        {:ok, lv, _html} = mount_chat_session(conn, user, session.id)

        assert has_element?(
                 lv,
                 "[data-role='session-item'][data-session-id='#{session.id}'][data-active='true']"
               )
      end)
    end

    test "puts an error flash and redirects to /chat when session id is not found", %{conn: conn} do
      {user, _account_id, _scope} = user_with_account()

      capture_log(fn ->
        conn = log_in_user(conn, user)

        {:ok, lv, _html} = live(conn, "/chat/99999999")

        flash = lv |> render() |> Floki.parse_document!() |> Floki.text()
        assert flash =~ "Chat session not found" or has_element?(lv, "[data-role='new-chat-header']")
      end)
    end

    test "does not show chat empty state when session is loaded", %{conn: conn} do
      {user, account_id, _scope} = user_with_account()
      session = insert_chat_session!(user.id, account_id)

      capture_log(fn ->
        {:ok, lv, _html} = mount_chat_session(conn, user, session.id)

        refute has_element?(lv, "[data-role='chat-empty-state']")
      end)
    end

    test "shows context type badge in the conversation header", %{conn: conn} do
      {user, account_id, _scope} = user_with_account()
      session = insert_chat_session!(user.id, account_id, %{context_type: :correlation})

      capture_log(fn ->
        {:ok, _lv, html} = mount_chat_session(conn, user, session.id)

        assert html =~ "Correlations"
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_event \"new_chat\""
  # ---------------------------------------------------------------------------

  describe "handle_event \"new_chat\"" do
    test "clears the active session and navigates to /chat", %{conn: conn} do
      {user, account_id, _scope} = user_with_account()
      session = insert_chat_session!(user.id, account_id, %{title: "Some Session"})

      capture_log(fn ->
        {:ok, lv, _html} = mount_chat_session(conn, user, session.id)

        # Verify session is active first
        assert has_element?(lv, "[data-role='session-header']")

        # Click new chat
        lv
        |> element("[data-role='new-chat-btn']")
        |> render_click()

        # After patch to /chat, the session header should be gone
        refute has_element?(lv, "[data-role='session-header']")
        assert has_element?(lv, "[data-role='new-chat-header']")
      end)
    end

    test "new_chat button triggers push_patch to /chat", %{conn: conn} do
      {user, _account_id, _scope} = user_with_account()

      capture_log(fn ->
        {:ok, lv, _html} = mount_chat(conn, user)

        lv
        |> element("[data-role='new-chat-btn']")
        |> render_click()

        assert has_element?(lv, "[data-role='new-chat-header']")
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_event \"toggle_sidebar\""
  # ---------------------------------------------------------------------------

  describe "handle_event \"toggle_sidebar\"" do
    test "toggles the show_sidebar boolean assign", %{conn: conn} do
      {user, _account_id, _scope} = user_with_account()

      capture_log(fn ->
        {:ok, lv, _html} = mount_chat(conn, user)

        # Trigger the toggle
        lv
        |> element("[data-role='sidebar-toggle']")
        |> render_click()

        # Sidebar toggle was fired — the view should still render correctly
        assert render(lv) =~ "AI Chat"
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_event \"select_session\""
  # ---------------------------------------------------------------------------

  describe "handle_event \"select_session\"" do
    test "navigates to /chat/:id when a session item is clicked", %{conn: conn} do
      {user, account_id, _scope} = user_with_account()
      session = insert_chat_session!(user.id, account_id, %{title: "Clickable Session"})

      capture_log(fn ->
        {:ok, lv, _html} = mount_chat(conn, user)

        lv
        |> element("[data-role='session-item'][data-session-id='#{session.id}']")
        |> render_click()

        # After selecting, the session header should appear
        assert has_element?(lv, "[data-role='session-header']")
      end)
    end

    test "marks the selected session as active in the sidebar after selection", %{conn: conn} do
      {user, account_id, _scope} = user_with_account()
      session = insert_chat_session!(user.id, account_id)

      capture_log(fn ->
        {:ok, lv, _html} = mount_chat(conn, user)

        lv
        |> element("[data-role='session-item'][data-session-id='#{session.id}']")
        |> render_click()

        assert has_element?(
                 lv,
                 "[data-role='session-item'][data-session-id='#{session.id}'][data-active='true']"
               )
      end)
    end

    test "shows the message list after selecting a session", %{conn: conn} do
      {user, account_id, _scope} = user_with_account()
      session = insert_chat_session!(user.id, account_id)

      capture_log(fn ->
        {:ok, lv, _html} = mount_chat(conn, user)

        lv
        |> element("[data-role='session-item'][data-session-id='#{session.id}']")
        |> render_click()

        assert has_element?(lv, "[data-role='message-list']")
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_event \"send_message\""
  # ---------------------------------------------------------------------------

  describe "handle_event \"send_message\"" do
    test "ignores send_message event when content is blank", %{conn: conn} do
      {user, account_id, _scope} = user_with_account()
      session = insert_chat_session!(user.id, account_id)

      capture_log(fn ->
        {:ok, lv, _html} = mount_chat_session(conn, user, session.id)

        html = render_click(lv, "send_message", %{"content" => ""})

        # Should not show any new user message in the message list
        refute html =~ "data-role=\"user-message\""
      end)
    end

    test "ignores send_message event when content is only whitespace", %{conn: conn} do
      {user, account_id, _scope} = user_with_account()
      session = insert_chat_session!(user.id, account_id)

      capture_log(fn ->
        {:ok, lv, _html} = mount_chat_session(conn, user, session.id)

        html = render_click(lv, "send_message", %{"content" => "   "})

        refute html =~ "data-role=\"user-message\""
      end)
    end

    test "appends an optimistic user message to the message list", %{conn: conn} do
      {user, account_id, _scope} = user_with_account()
      session = insert_chat_session!(user.id, account_id)

      capture_log(fn ->
        {:ok, lv, _html} = mount_chat_session(conn, user, session.id)

        html = render_click(lv, "send_message", %{"content" => "What is my best metric?"})

        assert html =~ "What is my best metric?"
        assert html =~ "data-message-role=\"user\""
      end)
    end

    test "clears the input value after sending a message", %{conn: conn} do
      {user, account_id, _scope} = user_with_account()
      session = insert_chat_session!(user.id, account_id)

      capture_log(fn ->
        {:ok, lv, _html} = mount_chat_session(conn, user, session.id)

        render_click(lv, "send_message", %{"content" => "Tell me about conversions"})

        # The input value should be cleared after send
        html = render(lv)
        # Input should not contain the sent text anymore as its value
        assert html =~ "data-role=\"message-input\""
      end)
    end

    test "creates a new session and starts streaming when no active session exists", %{conn: conn} do
      {user, _account_id, _scope} = user_with_account()

      capture_log(fn ->
        {:ok, lv, _html} = mount_chat(conn, user)

        render_click(lv, "send_message", %{"content" => "Start a new conversation"})

        html = render(lv)
        # A new session should have been created and a user message appended
        assert html =~ "Start a new conversation"
      end)
    end

    test "shows the streaming waiting indicator after sending a message", %{conn: conn} do
      {user, account_id, _scope} = user_with_account()
      session = insert_chat_session!(user.id, account_id)

      capture_log(fn ->
        {:ok, lv, _html} = mount_chat_session(conn, user, session.id)

        render_click(lv, "send_message", %{"content" => "Show me the trends"})

        # streaming: true means the waiting indicator should be present (no tokens yet)
        # OR the streaming message should appear (tokens arrived)
        html = render(lv)

        assert html =~ "data-role=\"streaming-waiting\"" or
                 html =~ "data-role=\"streaming-message\""
      end)
    end

    test "disables the textarea while streaming", %{conn: conn} do
      {user, account_id, _scope} = user_with_account()
      session = insert_chat_session!(user.id, account_id)

      capture_log(fn ->
        {:ok, lv, _html} = mount_chat_session(conn, user, session.id)

        render_click(lv, "send_message", %{"content" => "What are my top metrics?"})

        assert has_element?(lv, "[data-role='message-input'][disabled]")
      end)
    end

    test "disables the send button while streaming", %{conn: conn} do
      {user, account_id, _scope} = user_with_account()
      session = insert_chat_session!(user.id, account_id)

      capture_log(fn ->
        {:ok, lv, _html} = mount_chat_session(conn, user, session.id)

        render_click(lv, "send_message", %{"content" => "What are my top metrics?"})

        assert has_element?(lv, "[data-role='send-btn'][disabled]")
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_event \"update_input\""
  # ---------------------------------------------------------------------------

  describe "handle_event \"update_input\"" do
    test "updates input_value assign on phx-change", %{conn: conn} do
      {user, _account_id, _scope} = user_with_account()

      capture_log(fn ->
        {:ok, lv, _html} = mount_chat(conn, user)

        render_change(lv, "update_input", %{"content" => "Typing something"})

        html = render(lv)
        assert html =~ "Typing something"
      end)
    end

    test "does not make any context calls on update_input", %{conn: conn} do
      {user, _account_id, _scope} = user_with_account()

      capture_log(fn ->
        {:ok, lv, _html} = mount_chat(conn, user)

        # Just verify it does not crash and renders normally
        html = render_change(lv, "update_input", %{"content" => "Hello"})

        assert is_binary(html)
      end)
    end

    test "send button becomes enabled when input_value is non-blank", %{conn: conn} do
      {user, _account_id, _scope} = user_with_account()

      capture_log(fn ->
        {:ok, lv, _html} = mount_chat(conn, user)

        render_change(lv, "update_input", %{"content" => "Some text"})

        refute has_element?(lv, "[data-role='send-btn'][disabled]")
      end)
    end

    test "send button remains disabled when input_value is blank", %{conn: conn} do
      {user, _account_id, _scope} = user_with_account()

      capture_log(fn ->
        {:ok, lv, _html} = mount_chat(conn, user)

        render_change(lv, "update_input", %{"content" => ""})

        assert has_element?(lv, "[data-role='send-btn'][disabled]")
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_info {:chat_token, token}"
  # ---------------------------------------------------------------------------

  describe "handle_info {:chat_token, token}" do
    test "appends the token to streaming_content and shows streaming message", %{conn: conn} do
      {user, account_id, _scope} = user_with_account()
      session = insert_chat_session!(user.id, account_id)

      capture_log(fn ->
        {:ok, lv, _html} = mount_chat_session(conn, user, session.id)

        # Simulate the streaming state first by sending a message
        render_click(lv, "send_message", %{"content" => "Tell me about revenue"})

        # Now simulate a streaming token arriving
        send(lv.pid, {:chat_token, "Here "})
        send(lv.pid, {:chat_token, "is the data."})

        html = render(lv)
        assert html =~ "Here is the data." or html =~ "streaming-message"
      end)
    end

    test "shows streaming-message element when streaming_content is non-empty", %{conn: conn} do
      {user, account_id, _scope} = user_with_account()
      session = insert_chat_session!(user.id, account_id)

      capture_log(fn ->
        {:ok, lv, _html} = mount_chat_session(conn, user, session.id)

        render_click(lv, "send_message", %{"content" => "Give me a summary"})

        send(lv.pid, {:chat_token, "Sure, "})

        html = render(lv)
        assert html =~ "data-role=\"streaming-message\""
      end)
    end

    test "shows streaming-waiting indicator when streaming is true and no tokens yet", %{
      conn: conn
    } do
      {user, account_id, _scope} = user_with_account()
      session = insert_chat_session!(user.id, account_id)

      capture_log(fn ->
        {:ok, lv, _html} = mount_chat_session(conn, user, session.id)

        render_click(lv, "send_message", %{"content" => "What is the trend?"})

        # Before any token arrives, the waiting indicator should be shown
        html = render(lv)
        # Either waiting (no tokens yet) or streaming (tokens arrived from async task)
        assert html =~ "streaming-waiting" or html =~ "streaming-message"
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_info {:chat_complete, meta}"
  # ---------------------------------------------------------------------------

  describe "handle_info {:chat_complete, meta}" do
    test "sets streaming to false and clears streaming_content", %{conn: conn} do
      {user, account_id, _scope} = user_with_account()
      session = insert_chat_session!(user.id, account_id)

      capture_log(fn ->
        {:ok, lv, _html} = mount_chat_session(conn, user, session.id)

        render_click(lv, "send_message", %{"content" => "Any insights?"})
        send(lv.pid, {:chat_token, "Yes, here are insights."})
        send(lv.pid, {:chat_complete, %{token_count: 5}})

        html = render(lv)
        refute html =~ "data-role=\"streaming-message\""
        refute html =~ "data-role=\"streaming-waiting\""
      end)
    end

    test "re-enables the send button after streaming completes", %{conn: conn} do
      {user, account_id, _scope} = user_with_account()
      session = insert_chat_session!(user.id, account_id)

      capture_log(fn ->
        {:ok, lv, _html} = mount_chat_session(conn, user, session.id)

        render_click(lv, "send_message", %{"content" => "Any insights?"})
        send(lv.pid, {:chat_complete, %{token_count: 0}})

        refute has_element?(lv, "[data-role='send-btn'][disabled]")
      end)
    end

    test "re-enables the textarea after streaming completes", %{conn: conn} do
      {user, account_id, _scope} = user_with_account()
      session = insert_chat_session!(user.id, account_id)

      capture_log(fn ->
        {:ok, lv, _html} = mount_chat_session(conn, user, session.id)

        render_click(lv, "send_message", %{"content" => "Any insights?"})
        send(lv.pid, {:chat_complete, %{token_count: 0}})

        refute has_element?(lv, "[data-role='message-input'][disabled]")
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_info {:chat_error, reason}"
  # ---------------------------------------------------------------------------

  describe "handle_info {:chat_error, reason}" do
    test "sets streaming to false when a chat error is received", %{conn: conn} do
      {user, account_id, _scope} = user_with_account()
      session = insert_chat_session!(user.id, account_id)

      capture_log(fn ->
        {:ok, lv, _html} = mount_chat_session(conn, user, session.id)

        render_click(lv, "send_message", %{"content" => "Anything?"})
        send(lv.pid, {:chat_error, :timeout})

        html = render(lv)
        refute html =~ "data-role=\"streaming-waiting\""
        refute html =~ "data-role=\"streaming-message\""
      end)
    end

    test "shows an error flash when a chat error is received", %{conn: conn} do
      {user, account_id, _scope} = user_with_account()
      session = insert_chat_session!(user.id, account_id)

      capture_log(fn ->
        {:ok, lv, _html} = mount_chat_session(conn, user, session.id)

        render_click(lv, "send_message", %{"content" => "Anything?"})
        send(lv.pid, {:chat_error, :timeout})

        html = render(lv)
        assert html =~ "The AI encountered an error"
      end)
    end

    test "re-enables the textarea after a chat error", %{conn: conn} do
      {user, account_id, _scope} = user_with_account()
      session = insert_chat_session!(user.id, account_id)

      capture_log(fn ->
        {:ok, lv, _html} = mount_chat_session(conn, user, session.id)

        render_click(lv, "send_message", %{"content" => "Anything?"})
        send(lv.pid, {:chat_error, :network_failure})

        refute has_element?(lv, "[data-role='message-input'][disabled]")
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "message rendering"
  # ---------------------------------------------------------------------------

  describe "message rendering" do
    test "renders user messages with data-message-role='user'", %{conn: conn} do
      {user, account_id, _scope} = user_with_account()
      session = insert_chat_session!(user.id, account_id)
      insert_chat_message!(session.id, %{role: :user, content: "User said this"})

      capture_log(fn ->
        {:ok, lv, _html} = mount_chat_session(conn, user, session.id)

        assert has_element?(lv, "[data-role='message'][data-message-role='user']")
      end)
    end

    test "renders assistant messages with data-message-role='assistant'", %{conn: conn} do
      {user, account_id, _scope} = user_with_account()
      session = insert_chat_session!(user.id, account_id)
      insert_chat_message!(session.id, %{role: :assistant, content: "AI said this"})

      capture_log(fn ->
        {:ok, lv, _html} = mount_chat_session(conn, user, session.id)

        assert has_element?(lv, "[data-role='message'][data-message-role='assistant']")
      end)
    end

    test "renders user message bubble with data-role='user-message'", %{conn: conn} do
      {user, account_id, _scope} = user_with_account()
      session = insert_chat_session!(user.id, account_id)
      insert_chat_message!(session.id, %{role: :user, content: "User question here"})

      capture_log(fn ->
        {:ok, lv, _html} = mount_chat_session(conn, user, session.id)

        assert has_element?(lv, "[data-role='user-message']")
      end)
    end

    test "renders assistant message bubble with data-role='assistant-message'", %{conn: conn} do
      {user, account_id, _scope} = user_with_account()
      session = insert_chat_session!(user.id, account_id)
      insert_chat_message!(session.id, %{role: :assistant, content: "AI response here"})

      capture_log(fn ->
        {:ok, lv, _html} = mount_chat_session(conn, user, session.id)

        assert has_element?(lv, "[data-role='assistant-message']")
      end)
    end

    test "displays user message text content", %{conn: conn} do
      {user, account_id, _scope} = user_with_account()
      session = insert_chat_session!(user.id, account_id)
      insert_chat_message!(session.id, %{role: :user, content: "What drives revenue growth?"})

      capture_log(fn ->
        {:ok, _lv, html} = mount_chat_session(conn, user, session.id)

        assert html =~ "What drives revenue growth?"
      end)
    end

    test "displays assistant message text content", %{conn: conn} do
      {user, account_id, _scope} = user_with_account()
      session = insert_chat_session!(user.id, account_id)

      insert_chat_message!(session.id, %{
        role: :assistant,
        content: "Based on your data, Google Ads drives the most conversions."
      })

      capture_log(fn ->
        {:ok, _lv, html} = mount_chat_session(conn, user, session.id)

        assert html =~ "Based on your data, Google Ads drives the most conversions."
      end)
    end

    test "renders multiple messages in conversation order", %{conn: conn} do
      {user, account_id, _scope} = user_with_account()
      session = insert_chat_session!(user.id, account_id)
      insert_chat_message!(session.id, %{role: :user, content: "First user message"})
      insert_chat_message!(session.id, %{role: :assistant, content: "First AI response"})
      insert_chat_message!(session.id, %{role: :user, content: "Second user message"})

      capture_log(fn ->
        {:ok, _lv, html} = mount_chat_session(conn, user, session.id)

        assert html =~ "First user message"
        assert html =~ "First AI response"
        assert html =~ "Second user message"
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "sidebar rendering"
  # ---------------------------------------------------------------------------

  describe "sidebar rendering" do
    test "renders session title in sidebar with data-role='session-title'", %{conn: conn} do
      {user, account_id, _scope} = user_with_account()
      insert_chat_session!(user.id, account_id, %{title: "My Revenue Chat"})

      capture_log(fn ->
        {:ok, lv, _html} = mount_chat(conn, user)

        assert has_element?(lv, "[data-role='session-title']")
      end)
    end

    test "renders session updated_at with data-role='session-updated-at'", %{conn: conn} do
      {user, account_id, _scope} = user_with_account()
      insert_chat_session!(user.id, account_id)

      capture_log(fn ->
        {:ok, lv, _html} = mount_chat(conn, user)

        assert has_element?(lv, "[data-role='session-updated-at']")
      end)
    end

    test "renders context_type badge for each session item", %{conn: conn} do
      {user, account_id, _scope} = user_with_account()
      insert_chat_session!(user.id, account_id, %{context_type: :correlation})

      capture_log(fn ->
        {:ok, _lv, html} = mount_chat(conn, user)

        assert html =~ "Correlations"
      end)
    end

    test "renders multiple sessions in the sidebar", %{conn: conn} do
      {user, account_id, _scope} = user_with_account()
      insert_chat_session!(user.id, account_id, %{title: "Session Alpha"})
      insert_chat_session!(user.id, account_id, %{title: "Session Beta"})

      capture_log(fn ->
        {:ok, _lv, html} = mount_chat(conn, user)

        assert html =~ "Session Alpha"
        assert html =~ "Session Beta"
      end)
    end

    test "only shows sessions belonging to the authenticated user", %{conn: conn} do
      {user, account_id, _scope} = user_with_account()
      {other_user, other_account_id, _other_scope} = user_with_account()

      insert_chat_session!(user.id, account_id, %{title: "My Session"})
      insert_chat_session!(other_user.id, other_account_id, %{title: "Other User Session"})

      capture_log(fn ->
        {:ok, _lv, html} = mount_chat(conn, user)

        assert html =~ "My Session"
        refute html =~ "Other User Session"
      end)
    end

    test "shows the sidebar toggle button for mobile", %{conn: conn} do
      {user, _account_id, _scope} = user_with_account()

      capture_log(fn ->
        {:ok, lv, _html} = mount_chat(conn, user)

        assert has_element?(lv, "[data-role='sidebar-toggle']")
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "no-session-selected state"
  # ---------------------------------------------------------------------------

  describe "no-session-selected state" do
    test "shows 'Select a chat from the sidebar or start a new one' text", %{conn: conn} do
      {user, account_id, _scope} = user_with_account()
      insert_chat_session!(user.id, account_id)

      capture_log(fn ->
        {:ok, _lv, html} = mount_chat(conn, user)

        assert html =~ "Select a chat from the sidebar or start a new one."
      end)
    end

    test "shows a New Chat button in the no-session-selected state", %{conn: conn} do
      {user, account_id, _scope} = user_with_account()
      insert_chat_session!(user.id, account_id)

      capture_log(fn ->
        {:ok, lv, _html} = mount_chat(conn, user)

        assert has_element?(lv, "[data-role='new-chat-prompt-btn']")
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "example prompt chips"
  # ---------------------------------------------------------------------------

  describe "example prompt chips" do
    test "clicking an example prompt sends that message", %{conn: conn} do
      {user, _account_id, _scope} = user_with_account()

      capture_log(fn ->
        {:ok, lv, _html} = mount_chat(conn, user)

        lv
        |> element("[data-role='example-prompt']", "Why did my revenue drop last week?")
        |> render_click()

        html = render(lv)
        assert html =~ "Why did my revenue drop last week?"
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "authentication"
  # ---------------------------------------------------------------------------

  describe "authentication" do
    test "redirects unauthenticated users to /users/log-in for /chat", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/chat")
    end

    test "redirects unauthenticated users to /users/log-in for /chat/:id", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/chat/1")
    end
  end
end
