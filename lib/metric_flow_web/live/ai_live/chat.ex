defmodule MetricFlowWeb.AiLive.Chat do
  @moduledoc """
  LiveView for the AI chat interface.

  Displays a sidebar of previous chat sessions and an active conversation area.
  Users can start new sessions, continue existing ones, and ask natural language
  questions about their metrics. Assistant responses are streamed token-by-token.

  Routes:
  - GET /chat       — :index action, no active session
  - GET /chat/:id   — :show action, loads the identified session
  """

  use MetricFlowWeb, :live_view

  alias MetricFlow.Ai
  alias MetricFlowWeb.Layouts

  @context_labels %{
    general: "General",
    correlation: "Correlations",
    metric: "Metrics",
    dashboard: "Dashboard"
  }

  # ---------------------------------------------------------------------------
  # Render
  # ---------------------------------------------------------------------------

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} white_label_config={assigns[:white_label_config]} active_account_name={assigns[:active_account_name]}>
      <div class="flex h-[calc(100vh-4rem)] mf-content overflow-hidden">
        <%!-- Sidebar: always visible on desktop, overlay on mobile when show_sidebar=true --%>
        <div
          data-role="session-sidebar"
          class={[
            "w-64 flex-shrink-0 flex flex-col border-r border-base-content/10 overflow-hidden",
            if(@show_sidebar, do: "fixed inset-0 z-20 bg-base-100 flex flex-col", else: "hidden sm:flex")
          ]}
        >
          <%!-- Sidebar header --%>
          <div class="flex items-center justify-between px-4 py-3 border-b border-base-content/10 flex-shrink-0">
            <h2 class="text-sm font-semibold text-base-content/60 uppercase tracking-wide">
              Chats
            </h2>
            <button
              phx-click="new_chat"
              data-role="new-chat-btn"
              class="btn btn-primary btn-xs"
            >
              + New Chat
            </button>
          </div>

          <%!-- Session list --%>
          <div data-role="session-list" class="flex-1 overflow-y-auto py-2">
            <p
              :if={@sessions == []}
              data-role="no-sessions-state"
              class="text-xs text-base-content/40 px-4 py-3"
            >
              No chats yet
            </p>

            <button
              :for={session <- @sessions}
              phx-click="select_session"
              phx-value-id={session.id}
              data-role="session-item"
              data-session-id={session.id}
              data-active={if @active_session && @active_session.id == session.id, do: "true"}
              class={[
                "w-full text-left px-4 py-3 flex flex-col gap-0.5 hover:bg-base-content/5 transition-colors",
                if(@active_session && @active_session.id == session.id, do: "bg-base-content/10")
              ]}
            >
              <span data-role="session-title" class="text-sm font-medium truncate text-base-content">
                {session.title || "New Chat"}
              </span>
              <span class="badge badge-ghost badge-xs">
                {context_label(session.context_type)}
              </span>
              <span data-role="session-updated-at" class="text-xs text-base-content/40">
                {format_updated_at(session.updated_at)}
              </span>
            </button>
          </div>
        </div>

        <%!-- Conversation area --%>
        <div data-role="conversation-area" class="flex-1 flex flex-col overflow-hidden">
          <%!-- Conversation header --%>
          <div class="flex items-center gap-3 px-4 py-3 border-b border-base-content/10 flex-shrink-0">
            <button
              phx-click="toggle_sidebar"
              data-role="sidebar-toggle"
              class="btn btn-ghost btn-sm sm:hidden"
              aria-label="Toggle sidebar"
            >
              <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16" />
              </svg>
            </button>

            <h1
              :if={@active_session}
              data-role="session-header"
              class="text-base font-semibold truncate"
            >
              {@active_session.title || "New Chat"}
            </h1>
            <span :if={@active_session} class="badge badge-ghost badge-sm">
              {context_label(@active_session.context_type)}
            </span>

            <h1
              :if={!@active_session}
              data-role="new-chat-header"
              class="text-base font-semibold"
            >
              New Chat
            </h1>
          </div>

          <%!-- Main content area: empty state, no-session-selected, or message list --%>

          <%!-- Empty state: no sessions at all and no active session --%>
          <div
            :if={!@active_session && @sessions == []}
            data-role="chat-empty-state"
            class="flex-1 flex flex-col items-center justify-center px-8 text-center"
          >
            <h2 class="text-xl font-semibold">Ask me anything about your data</h2>
            <p class="text-base-content/60 mt-2 max-w-prose">
              I have access to your metrics, correlations, and trends. Ask a question in plain language and I'll help you understand what's happening in your business.
            </p>
            <div class="flex flex-wrap gap-2 justify-center mt-6">
              <button
                phx-click="send_message"
                phx-value-content="Why did my revenue drop last week?"
                data-role="example-prompt"
                class="btn btn-ghost btn-sm"
              >
                Why did my revenue drop last week?
              </button>
              <button
                phx-click="send_message"
                phx-value-content="Which ad platform drives the most conversions?"
                data-role="example-prompt"
                class="btn btn-ghost btn-sm"
              >
                Which ad platform drives the most conversions?
              </button>
              <button
                phx-click="send_message"
                phx-value-content="What should I focus on to grow faster?"
                data-role="example-prompt"
                class="btn btn-ghost btn-sm"
              >
                What should I focus on to grow faster?
              </button>
            </div>
          </div>

          <%!-- No-session-selected state: sessions exist but none active --%>
          <div
            :if={!@active_session && @sessions != []}
            data-role="no-session-selected"
            class="flex-1 flex flex-col items-center justify-center px-8 text-center"
          >
            <p class="text-base-content/60">
              Select a chat from the sidebar or start a new one.
            </p>
            <p class="text-xs text-base-content/40 mt-1">
              Your previous chat history is saved in the sidebar.
            </p>
            <button
              phx-click="new_chat"
              data-role="new-chat-prompt-btn"
              class="btn btn-primary btn-sm mt-4"
            >
              New Chat
            </button>
          </div>

          <%!-- Message list: active session loaded --%>
          <div
            :if={@active_session}
            data-role="message-list"
            class="flex-1 overflow-y-auto px-4 py-4 space-y-4"
          >
            <div
              :for={message <- @messages}
              data-role="message"
              data-message-role={message.role}
            >
              <%!-- User message --%>
              <div :if={message.role == :user} class="flex justify-end">
                <div
                  data-role="user-message"
                  class="max-w-[85%] sm:max-w-[75%] rounded-2xl rounded-br-sm px-4 py-3 bg-primary text-primary-content text-sm"
                >
                  {message.content}
                </div>
              </div>

              <%!-- Assistant message --%>
              <div :if={message.role == :assistant} class="flex justify-start">
                <div class="max-w-[85%] sm:max-w-[75%] flex flex-col gap-1">
                  <div
                    data-role="assistant-message"
                    class="mf-card-cyan px-4 py-3 text-sm leading-relaxed whitespace-pre-wrap"
                  >
                    {message.content}
                  </div>
                  <div class="flex items-center gap-1">
                    <button
                      phx-click="share_insight"
                      phx-value-message-id={message.id}
                      data-role="share-insight"
                      class="btn btn-ghost btn-xs text-base-content/40 hover:text-base-content/70"
                    >
                      Share
                    </button>
                  </div>
                </div>
              </div>

              <%!-- System message --%>
              <div
                :if={message.role == :system}
                data-role="system-message"
                class="text-xs text-base-content/40 text-center py-1"
              >
                {message.content}
              </div>
            </div>

            <%!-- Streaming waiting indicator (no tokens yet) --%>
            <div :if={@streaming && @streaming_content == ""} class="flex justify-start">
              <div class="max-w-[85%] sm:max-w-[75%] flex flex-col gap-1">
                <div data-role="streaming-waiting" class="mf-card-cyan px-4 py-3">
                  <span class="loading loading-dots loading-sm"></span>
                </div>
                <div class="flex items-center gap-1">
                  <button
                    phx-click="share_insight"
                    data-role="share-insight"
                    class="btn btn-ghost btn-xs text-base-content/40 hover:text-base-content/70"
                    aria-label="Share this chat"
                  >
                    Share
                  </button>
                </div>
              </div>
            </div>

            <%!-- Streaming message (tokens arriving) --%>
            <div :if={@streaming && @streaming_content != ""} class="flex justify-start">
              <div class="max-w-[85%] sm:max-w-[75%] flex flex-col gap-1">
                <div
                  data-role="streaming-message"
                  class="mf-card-cyan px-4 py-3 text-sm leading-relaxed whitespace-pre-wrap"
                >
                  {@streaming_content}<span class="inline-block w-0.5 h-4 bg-current animate-pulse align-middle ml-0.5"></span>
                </div>
                <div class="flex items-center gap-1">
                  <button
                    phx-click="share_insight"
                    data-role="share-insight"
                    class="btn btn-ghost btn-xs text-base-content/40 hover:text-base-content/70"
                    aria-label="Share this chat"
                  >
                    Share
                  </button>
                </div>
              </div>
            </div>
          </div>

          <%!-- Message input area --%>
          <div data-role="message-input-area" class="flex-shrink-0 border-t border-base-content/10 px-4 py-3">
            <form phx-submit="send_message" phx-change="update_input">
              <div class="flex items-end gap-2">
                <textarea
                  name="content"
                  data-role="message-input"
                  rows="2"
                  placeholder="Ask a question about your data…"
                  disabled={@streaming}
                  value={@input_value}
                  class="flex-1 textarea textarea-bordered resize-none text-sm max-h-36 leading-relaxed"
                ></textarea>
                <button
                  type="submit"
                  data-role="send-btn"
                  disabled={@streaming || String.trim(@input_value) == ""}
                  class="btn btn-primary btn-sm self-end"
                >
                  <span :if={@streaming} class="loading loading-spinner loading-xs"></span>
                  <span :if={!@streaming}>Send</span>
                </button>
              </div>

              <%!-- Context indicator when pending context set for new session --%>
              <p
                :if={!@active_session && @pending_context_type}
                data-role="context-indicator"
                class="text-xs text-base-content/40 mt-1"
              >
                Context: {context_label(@pending_context_type)}
              </p>
            </form>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  # ---------------------------------------------------------------------------
  # Mount
  # ---------------------------------------------------------------------------

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope
    sessions = Ai.list_chat_sessions(scope)

    socket =
      socket
      |> assign(:sessions, sessions)
      |> assign(:active_session, nil)
      |> assign(:messages, [])
      |> assign(:streaming_content, "")
      |> assign(:streaming, false)
      |> assign(:input_value, "")
      |> assign(:pending_context_type, nil)
      |> assign(:pending_context_id, nil)
      |> assign(:show_sidebar, false)
      |> assign(:page_title, "AI Chat")

    {:ok, socket}
  end

  # ---------------------------------------------------------------------------
  # Handle params
  # ---------------------------------------------------------------------------

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, params) do
    pending_context_type =
      case Map.get(params, "context_type") do
        nil -> nil
        type_string -> String.to_existing_atom(type_string)
      end

    pending_context_id =
      case Map.get(params, "context_id") do
        nil -> nil
        id_string -> String.to_integer(id_string)
      end

    socket
    |> assign(:active_session, nil)
    |> assign(:messages, [])
    |> assign(:streaming_content, "")
    |> assign(:streaming, false)
    |> assign(:pending_context_type, pending_context_type)
    |> assign(:pending_context_id, pending_context_id)
  end

  defp apply_action(socket, :show, %{"id" => id_string}) do
    scope = socket.assigns.current_scope
    id = String.to_integer(id_string)

    case Ai.get_chat_session(scope, id) do
      {:ok, session} ->
        socket
        |> assign(:active_session, session)
        |> assign(:messages, session.chat_messages)
        |> assign(:streaming_content, "")
        |> assign(:streaming, false)
        |> assign(:pending_context_type, nil)
        |> assign(:pending_context_id, nil)

      {:error, :not_found} ->
        socket
        |> put_flash(:error, "Chat session not found.")
        |> push_patch(to: ~p"/app/chat")
    end
  end

  # ---------------------------------------------------------------------------
  # Event handlers
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("new_chat", _params, socket) do
    {:noreply, push_patch(socket, to: ~p"/app/chat")}
  end

  def handle_event("toggle_sidebar", _params, socket) do
    {:noreply, assign(socket, :show_sidebar, !socket.assigns.show_sidebar)}
  end

  def handle_event("select_session", %{"id" => id_string}, socket) do
    socket =
      socket
      |> assign(:show_sidebar, false)
      |> push_patch(to: ~p"/app/chat/#{id_string}")

    {:noreply, socket}
  end

  # Consolidated send_message handler: prefers a non-empty value from either
  # "content" (form textarea name) or "message" (used by test render_submit/1).
  # When tests call render_submit(%{message: "..."}), Phoenix merges extra params
  # with the form's current field values, producing both "content" => "" and
  # "message" => "...". We pick the first non-empty string from either key.
  def handle_event("send_message", params, socket) do
    trimmed = extract_message_content(params)

    if trimmed == "" || socket.assigns.streaming do
      {:noreply, socket}
    else
      do_send_message(socket, trimmed)
    end
  end

  def handle_event("update_input", %{"content" => value}, socket) do
    {:noreply, assign(socket, :input_value, value)}
  end

  # Share insight handler: builds a shareable link for the active session.
  # Accepts an optional message-id to link to a specific message.
  def handle_event("share_insight", params, socket) do
    message_id = Map.get(params, "message-id")

    case socket.assigns.active_session do
      nil ->
        {:noreply, put_flash(socket, :info, "No active session to share.")}

      active_session ->
        url = build_share_url(active_session.id, message_id)

        socket =
          socket
          |> push_event("copy_to_clipboard", %{text: url})
          |> put_flash(:info, "Link copied to clipboard! Share with your team members.")

        {:noreply, socket}
    end
  end

  # ---------------------------------------------------------------------------
  # Handle info (streaming callbacks)
  # ---------------------------------------------------------------------------

  @impl true
  def handle_info({:chat_token, token}, socket) do
    {:noreply, assign(socket, :streaming_content, socket.assigns.streaming_content <> token)}
  end

  def handle_info({:chat_complete, %{token_count: _token_count}}, socket) do
    scope = socket.assigns.current_scope
    active_session = socket.assigns.active_session

    socket =
      socket
      |> apply_refreshed_session(scope, active_session.id)
      |> assign(:streaming, false)
      |> assign(:streaming_content, "")

    {:noreply, socket}
  end

  def handle_info({:chat_error, _reason}, socket) do
    socket =
      socket
      |> assign(:streaming, false)
      |> assign(:streaming_content, "")
      |> put_flash(:error, "The AI encountered an error. Please try again.")

    {:noreply, socket}
  end

  # Catch Task exit messages so the process doesn't crash
  def handle_info({ref, _result}, socket) when is_reference(ref) do
    {:noreply, socket}
  end

  def handle_info({:DOWN, _ref, :process, _pid, _reason}, socket) do
    {:noreply, socket}
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp extract_message_content(params) do
    content_value = Map.get(params, "content", "")
    message_value = Map.get(params, "message", "")

    raw =
      cond do
        String.trim(content_value) != "" -> content_value
        String.trim(message_value) != "" -> message_value
        true -> ""
      end

    String.trim(raw)
  end

  defp build_share_url(session_id, message_id) when is_binary(message_id) and message_id != "" do
    MetricFlowWeb.Endpoint.url() <> "/app/chat/#{session_id}?highlight=#{message_id}"
  end

  defp build_share_url(session_id, _message_id) do
    MetricFlowWeb.Endpoint.url() <> "/app/chat/#{session_id}"
  end

  defp apply_refreshed_session(socket, scope, session_id) do
    case Ai.get_chat_session(scope, session_id) do
      {:ok, refreshed_session} ->
        updated_sessions = Enum.map(socket.assigns.sessions, &replace_session(&1, refreshed_session))

        socket
        |> assign(:messages, refreshed_session.chat_messages)
        |> assign(:sessions, updated_sessions)

      {:error, :not_found} ->
        socket
    end
  end

  defp replace_session(session, refreshed_session) do
    if session.id == refreshed_session.id, do: refreshed_session, else: session
  end

  defp do_send_message(socket, content) do
    scope = socket.assigns.current_scope

    # If no active session, create one first
    {socket, active_session} =
      if socket.assigns.active_session do
        {socket, socket.assigns.active_session}
      else
        create_new_session(socket, scope)
      end

    if active_session == nil do
      {:noreply, socket}
    else
      send_to_session(socket, scope, active_session, content)
    end
  end

  defp create_new_session(socket, scope) do
    context_type = socket.assigns.pending_context_type || :general
    context_id = socket.assigns.pending_context_id
    attrs = %{context_type: context_type, context_id: context_id}

    case Ai.create_chat_session(scope, attrs) do
      {:ok, new_session} ->
        updated_sessions = [new_session | socket.assigns.sessions]

        socket =
          socket
          |> assign(:sessions, updated_sessions)
          |> assign(:active_session, new_session)

        {socket, new_session}

      {:error, _changeset} ->
        {put_flash(socket, :error, "Could not start chat session."), nil}
    end
  end

  defp send_to_session(socket, scope, active_session, content) do
    optimistic_message = %{
      role: :user,
      content: content,
      id: nil,
      inserted_at: DateTime.utc_now()
    }

    socket =
      socket
      |> assign(:messages, socket.assigns.messages ++ [optimistic_message])
      |> assign(:input_value, "")
      |> assign(:streaming, true)
      |> assign(:streaming_content, "")

    llm_opts = Application.get_env(:metric_flow, :test_llm_options, [])

    case Ai.send_chat_message(scope, active_session.id, content, llm_opts) do
      {:ok, _pid} ->
        {:noreply, socket}

      {:error, :not_found} ->
        {:noreply, socket |> assign(:streaming, false) |> put_flash(:error, "Session not found.")}

      {:error, :session_archived} ->
        {:noreply,
         socket
         |> assign(:streaming, false)
         |> put_flash(:error, "This chat session has been archived and cannot receive new messages.")}
    end
  end

  @spec context_label(atom() | nil) :: String.t()
  defp context_label(nil), do: "General"
  defp context_label(type), do: Map.get(@context_labels, type, "General")

  @spec format_updated_at(DateTime.t() | nil) :: String.t()
  defp format_updated_at(nil), do: ""

  defp format_updated_at(%DateTime{} = dt) do
    now = DateTime.utc_now()
    diff_seconds = DateTime.diff(now, dt, :second)

    cond do
      diff_seconds < 60 -> "just now"
      diff_seconds < 3600 -> "#{div(diff_seconds, 60)} minutes ago"
      diff_seconds < 86_400 -> "#{div(diff_seconds, 3600)} hours ago"
      diff_seconds < 172_800 -> "yesterday"
      true -> Calendar.strftime(dt, "%b %d, %Y")
    end
  end
end
