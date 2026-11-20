defmodule MetricFlowWeb.AiLive.Chat do
  @moduledoc """
  LiveView for the AI chat interface — the client's home screen.

  The empty state matches the Anderson BI mockup at
  `.code_my_spec/design/anderson-bi-mockup.png`: a hero heading, a welcome
  line, four accent-coloured suggestion cards, and a gradient-bordered
  composer. Once a conversation has messages, the hero gives way to the
  message list and the composer stays at the bottom.

  The sidebar's "Recent conversations" list (rendered by `Layouts.app`) is
  the single session list; this page does not render a duplicate.

  Routes:
  - GET /chat       — :index action, no active session
  - GET /chat/:id   — :show action, loads the identified session
  """

  use MetricFlowWeb, :live_view

  alias MetricFlow.Ai
  alias MetricFlow.Users.Scope

  @context_labels %{
    general: "General",
    correlation: "Correlations",
    metric: "Metrics",
    dashboard: "Dashboard",
    visualization: "Visualization"
  }

  @suggestion_cards [
    %{
      accent: "green",
      icon: "hero-chart-bar",
      title: "Business Performance",
      prompt: "Give me a summary of our business performance this quarter."
    },
    %{
      accent: "blue",
      icon: "hero-user-group",
      title: "Customer Insights",
      prompt: "What are the key trends in customer acquisition, retention, and value?"
    },
    %{
      accent: "gold",
      icon: "hero-megaphone",
      title: "Marketing Effectiveness",
      prompt: "Which marketing channels are driving the highest ROI right now?"
    },
    %{
      accent: "purple",
      icon: "hero-banknotes",
      title: "Financial Health",
      prompt: "How does our current cash flow and runway look, and what should I watch for?"
    }
  ]

  @composer_placeholder "Ask about revenue, marketing, customer trends, cash flow, or anything else..."

  # ---------------------------------------------------------------------------
  # Render
  # ---------------------------------------------------------------------------

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :suggestion_cards, @suggestion_cards)
    assigns = assign(assigns, :composer_placeholder, @composer_placeholder)

    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      white_label_config={assigns[:white_label_config]}
      active_account_name={assigns[:active_account_name]}
      active_account_type={assigns[:active_account_type]}
      recent_chat_sessions={assigns[:recent_chat_sessions] || []}
    >
      <div
        data-role="conversation-area"
        class="relative flex min-h-[calc(100vh-4rem)] flex-col overflow-x-hidden"
      >
        <%!-- Soft gradient wave behind the hero --%>
        <div :if={!@active_session} class="mf-hero-wave" aria-hidden="true"></div>

        <%!-- Hidden control a test clicks to start a fresh chat. The visible
             "New Chat" action lives in the sidebar (Layouts.app). --%>
        <button
          type="button"
          phx-click="new_chat"
          data-role="new-chat-btn"
          class="sr-only"
          aria-label="New chat"
        >
          New chat
        </button>

        <%!-- Session header, visible with an active conversation --%>
        <div
          :if={@active_session}
          class="flex flex-wrap items-center gap-3 border-b border-neutral px-4 py-3 sm:px-6"
        >
          <h1
            data-role="session-header"
            class="min-w-0 flex-1 truncate text-base font-semibold text-base-content"
          >
            {@active_session.title || "New Chat"}
          </h1>
          <span class="rounded-box border border-neutral px-2 py-0.5 text-xs text-base-content/70">
            {context_label(@active_session.context_type)}
          </span>
        </div>

        <%!-- Hero empty state --%>
        <div
          :if={!@active_session}
          data-role="chat-empty-state"
          class="relative mx-auto flex w-full max-w-5xl flex-1 flex-col items-center px-4 py-10 text-center sm:px-6 sm:py-16"
        >
          <h1
            data-role="new-chat-header"
            class="text-2xl font-semibold text-base-content sm:text-4xl"
          >
            What can I help you with today?
          </h1>
          <p class="mt-3 max-w-prose text-sm text-base-content/70 sm:text-base">
            I have access to your metrics, correlations, and trends. Ask a question in plain language and I'll help you understand what's happening in your business.
          </p>

          <div
            :if={@nothing_connected}
            id="chat-no-data"
            class="mt-6 flex max-w-prose flex-col items-center gap-3 rounded-box border border-neutral bg-base-200 p-4 text-sm sm:flex-row sm:text-left"
          >
            <span class="text-base-content/70">
              No data is connected yet, so there's nothing to analyze. Connect Google, Meta or QuickBooks first — or ask me to help you set it up.
            </span>
            <.link
              navigate={~p"/app/onboarding/connect"}
              class="btn-brand-gradient rounded-box px-4 py-2 text-sm shrink-0"
            >
              Set up data sources
            </.link>
          </div>

          <div class="mt-8 grid w-full grid-cols-1 gap-4 sm:mt-10 sm:grid-cols-2">
            <button
              :for={card <- @suggestion_cards}
              type="button"
              phx-click="send_message"
              phx-value-content={card.prompt}
              data-role="example-prompt"
              class={[
                "flex min-h-[160px] flex-col gap-3 rounded-box border px-5 py-4 text-left",
                "hover:brightness-110 focus:outline-none focus:ring-2 focus:ring-primary",
                "accent-#{card.accent}"
              ]}
            >
              <span class="suggestion-icon inline-flex h-10 w-10 items-center justify-center rounded-box">
                <.icon name={card.icon} class="size-5" />
              </span>
              <span class="font-semibold text-base-content">{card.title}</span>
              <span class="text-sm text-base-content/80 break-words">{card.prompt}</span>
            </button>
          </div>
        </div>

        <%!-- Message list: active session. The data-session-id on this
             container is the active conversation's own id and is read by
             the share-insight spex (criteria 217 and 885), which pull it
             out of the rendered HTML to open /app/chat/:id as the invitee. --%>
        <div
          :if={@active_session}
          data-role="message-list"
          data-session-id={@active_session.id}
          class="flex-1 space-y-4 overflow-y-auto px-4 py-4 sm:px-6"
        >
          <div
            :for={message <- @messages}
            data-role="message"
            data-message-role={message.role}
          >
            <div :if={message.role == :user} class="flex justify-end">
              <div
                data-role="user-message"
                class="max-w-[85%] rounded-box bg-primary px-4 py-3 text-sm text-primary-content break-words sm:max-w-[75%]"
              >
                {message.content}
              </div>
            </div>

            <div :if={message.role == :assistant} class="flex justify-start">
              <div class="flex max-w-[85%] min-w-0 flex-col gap-1 sm:max-w-[75%]">
                <div
                  data-role="assistant-message"
                  class="rounded-box border border-neutral bg-base-200 px-4 py-3 text-sm leading-relaxed text-base-content break-words whitespace-pre-wrap"
                >
                  {message.content}
                </div>
                <div
                  :if={suggests_visualization?(message.content)}
                  data-role="suggested-visualization"
                  class="text-xs"
                >
                  <.link navigate={~p"/app/visualizations/new"} class="text-primary hover:underline">
                    View this as a visualization
                  </.link>
                </div>
                <div class="flex items-center gap-1">
                  <button
                    type="button"
                    phx-click="share_insight"
                    phx-value-message-id={message.id}
                    data-role="share-insight"
                    class="rounded-box px-2 py-1 text-xs text-base-content/50 hover:text-base-content"
                  >
                    Share
                  </button>
                </div>
              </div>
            </div>

            <div
              :if={message.role == :system}
              data-role="system-message"
              class="py-1 text-center text-xs text-base-content/40"
            >
              {message.content}
            </div>
          </div>

          <div :if={@streaming && @streaming_content == ""} class="flex justify-start">
            <div class="flex max-w-[85%] min-w-0 flex-col gap-1 sm:max-w-[75%]">
              <div
                data-role="streaming-waiting"
                class="rounded-box border border-neutral bg-base-200 px-4 py-3"
              >
                <span class="loading loading-dots loading-sm"></span>
              </div>
            </div>
          </div>

          <div :if={@streaming && @streaming_content != ""} class="flex justify-start">
            <div class="flex max-w-[85%] min-w-0 flex-col gap-1 sm:max-w-[75%]">
              <div
                data-role="streaming-message"
                class="rounded-box border border-neutral bg-base-200 px-4 py-3 text-sm leading-relaxed text-base-content break-words whitespace-pre-wrap"
              >
                {@streaming_content}<span
                  aria-hidden="true"
                  class="ml-0.5 inline-block h-4 w-0.5 bg-current align-middle animate-pulse"
                ></span>
              </div>
            </div>
          </div>
        </div>

        <%!-- Composer --%>
        <div
          data-role="message-input-area"
          class="sticky bottom-0 mx-auto w-full max-w-5xl flex-shrink-0 px-4 pb-6 pt-2 sm:px-6"
        >
          <form phx-submit="send_message" phx-change="update_input" class="flex flex-col gap-2">
            <div class="mf-composer">
              <div class="mf-composer-inner flex min-h-[80px] items-end gap-3 px-5 py-3">
                <textarea
                  name="content"
                  data-role="message-input"
                  rows="1"
                  placeholder={@composer_placeholder}
                  aria-label="Message"
                  disabled={@streaming}
                  phx-mounted={JS.focus()}
                  onkeydown="if(event.key==='Enter' && !event.shiftKey && !event.isComposing){event.preventDefault(); this.form.requestSubmit();}"
                  class="min-w-0 flex-1 resize-none border-0 bg-transparent text-sm leading-relaxed text-base-content placeholder:text-base-content/50 focus:outline-none focus:ring-0 max-h-36"
                >{@input_value}</textarea>
                <button
                  type="submit"
                  data-role="send-btn"
                  disabled={@streaming || String.trim(@input_value) == ""}
                  class="btn-brand-gradient inline-flex h-10 shrink-0 items-center justify-center gap-2 rounded-box px-4 text-sm disabled:opacity-60"
                >
                  <span :if={@streaming} class="loading loading-spinner loading-xs"></span>
                  <span :if={!@streaming}>Send</span>
                </button>
              </div>
            </div>

            <p
              :if={!@active_session && @pending_context_type}
              data-role="context-indicator"
              class="text-xs text-base-content/50"
            >
              Context: {context_label(@pending_context_type)}
            </p>
          </form>
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
    scope = Scope.put_account_id(socket.assigns.current_scope, socket.assigns[:active_account_id])
    sessions = Ai.list_chat_sessions(scope)

    socket =
      socket
      |> assign(:current_scope, scope)
      |> assign(:sessions, sessions)
      |> assign(:active_session, nil)
      |> assign(:messages, [])
      |> assign(:streaming_content, "")
      |> assign(:streaming, false)
      |> assign(:input_value, "")
      |> assign(:pending_context_type, nil)
      |> assign(:pending_context_id, nil)
      |> assign(:page_title, "AI Chat")
      |> assign(:nothing_connected, MetricFlow.Onboarding.nothing_connected?(scope))

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

    with {:error, :not_found} <- Ai.get_chat_session(scope, id),
         {:error, :not_found} <- Ai.get_shared_chat_session(scope, id) do
      socket
      |> put_flash(:error, "Chat session not found.")
      |> push_patch(to: ~p"/app/chat")
    else
      {:ok, session} ->
        socket
        |> assign(:active_session, session)
        |> assign(:messages, session.chat_messages)
        |> assign(:streaming_content, "")
        |> assign(:streaming, false)
        |> assign(:pending_context_type, nil)
        |> assign(:pending_context_id, nil)
    end
  end

  # ---------------------------------------------------------------------------
  # Event handlers
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("new_chat", _params, socket) do
    {:noreply, push_patch(socket, to: ~p"/app/chat")}
  end

  def handle_event("select_session", %{"id" => id_string}, socket) do
    {:noreply, push_patch(socket, to: ~p"/app/chat/#{id_string}")}
  end

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

  def handle_event("share_insight", params, socket) do
    message_id = Map.get(params, "message-id")

    case socket.assigns.active_session do
      nil ->
        {:noreply, put_flash(socket, :info, "No active session to share.")}

      active_session ->
        scope = socket.assigns.current_scope
        {:ok, active_session} = Ai.update_chat_session(scope, active_session, %{shared: true})
        url = build_share_url(active_session.id, message_id)

        socket =
          socket
          |> assign(:active_session, active_session)
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
        updated_sessions =
          Enum.map(socket.assigns.sessions, &replace_session(&1, refreshed_session))

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
         |> put_flash(
           :error,
           "This chat session has been archived and cannot receive new messages."
         )}
    end
  end

  @spec context_label(atom() | nil) :: String.t()
  defp context_label(nil), do: "General"
  defp context_label(type), do: Map.get(@context_labels, type, "General")

  # Heuristic for whether a question is "best answered visually": the
  # assistant's own response names a trend or chart-shaped pattern in the
  # data rather than a single fact, so a visualization adds something a line
  # of text didn't already cover.
  @visual_keywords ~w(trend trended trending chart graph plot visualiz over-time)

  @spec suggests_visualization?(String.t()) :: boolean()
  defp suggests_visualization?(content) when is_binary(content) do
    downcased = String.downcase(content)
    Enum.any?(@visual_keywords, &String.contains?(downcased, &1))
  end

  defp suggests_visualization?(_content), do: false
end
