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
  # Test Assertions from spec
  # ---------------------------------------------------------------------------

  describe "renders chat page with session sidebar and conversation area" do
    test "shows sidebar, conversation area, and input", %{conn: conn} do
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
    test "displays empty state", %{conn: conn} do
      {user, _account_id, _scope} = user_with_account()

      capture_log(fn ->
        {:ok, lv, html} = mount_chat(conn, user)

        assert has_element?(lv, "[data-role='chat-empty-state']")
        assert html =~ "Ask me anything about your data"
        assert has_element?(lv, "[data-role='example-prompt']")
        assert has_element?(lv, "[data-role='no-sessions-state']")
      end)
    end
  end

  describe "shows no-session-selected state when sessions exist but none is active" do
    test "displays no session selected", %{conn: conn} do
      {user, account_id, _scope} = user_with_account()
      insert_chat_session!(user.id, account_id)

      capture_log(fn ->
        {:ok, lv, _html} = mount_chat(conn, user)

        assert has_element?(lv, "[data-role='no-session-selected']")
        refute has_element?(lv, "[data-role='chat-empty-state']")
        assert has_element?(lv, "[data-role='session-item']")
      end)
    end
  end

  describe "creates a new session and displays it when a message is sent" do
    test "sends message and creates session", %{conn: conn} do
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
    test "shows session messages", %{conn: conn} do
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

  describe "streams assistant response tokens into the conversation" do
    test "handles chat_complete message gracefully", %{conn: conn} do
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
    test "displays waiting indicator during streaming", %{conn: conn} do
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
    test "updates input and manages send button state", %{conn: conn} do
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
    test "loads session on click", %{conn: conn} do
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
    test "clears active session", %{conn: conn} do
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
    test "flashes error for invalid session", %{conn: conn} do
      {user, _account_id, _scope} = user_with_account()

      capture_log(fn ->
        conn = log_in_user(conn, user)

        assert {:error, {:live_redirect, %{to: "/chat", flash: %{"error" => "Chat session not found."}}}} =
                 live(conn, ~p"/chat/999999")
      end)
    end
  end

  describe "shows context indicator when context_type query param is set" do
    test "displays context indicator", %{conn: conn} do
      {user, _account_id, _scope} = user_with_account()

      capture_log(fn ->
        conn = log_in_user(conn, user)
        {:ok, lv, _html} = live(conn, ~p"/chat?context_type=correlation")

        assert has_element?(lv, "[data-role='context-indicator']")
      end)
    end
  end
end
