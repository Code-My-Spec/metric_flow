# MetricFlowWeb.AiLive.Chat

AI chat interface for data exploration. Displays a sidebar of previous chat sessions alongside an active conversation area. Users can start new sessions, continue existing ones, and ask natural language questions about their metrics. Assistant responses are streamed token-by-token.

## Type

liveview

## Route

- `/chat` — index action, no active session selected
- `/chat/:id` — show action, loads the identified session

## Params

- `id` - integer, chat session ID (`:show` action only)
- `context_type` - string, optional query param on `/chat`; sets the context type for a new session (e.g. `"general"`, `"correlation"`, `"metric"`, `"dashboard"`)
- `context_id` - integer, optional query param on `/chat`; identifies the domain object associated with the context

## Dependencies

- MetricFlow.Ai

## Components

None

## User Interactions

- **mount**: Reads `current_scope` from socket assigns. Calls `Ai.list_chat_sessions(scope)` to load all sessions for the account. Assigns `sessions`, `active_session: nil`, `messages: []`, `streaming: false`, `streaming_content: ""`, `input_value: ""`, `pending_context_type: nil`, `pending_context_id: nil`, `show_sidebar: false`, and `page_title: "AI Chat"`. Requires authentication; unauthenticated requests redirect to `/users/log-in`.

- **handle_params (`:index`)**: Clears active session and message state. Reads optional `context_type` and `context_id` query params and assigns them as `pending_context_type` and `pending_context_id` for use when the next session is created.

- **handle_params (`:show`)**: Calls `Ai.get_chat_session(scope, id)`. On success, assigns `active_session`, `messages` (from `session.chat_messages`), and clears streaming state and pending context. On `:not_found`, puts an error flash and redirects to `/chat` via `push_patch`.

- **phx-click="new_chat"**: Navigates to `/chat` via `push_patch`, clearing the active session. Triggered by the "+ New Chat" button in the sidebar header and the "New Chat" button in the no-session-selected state.

- **phx-click="toggle_sidebar"**: Toggles the `show_sidebar` boolean assign. On mobile, this shows or hides the session sidebar as a full-screen overlay. The toggle button is visible only below the `sm` breakpoint.

- **phx-click="select_session"** (id: string): Closes the sidebar overlay (`show_sidebar: false`) and navigates to `/chat/:id` via `push_patch`. Triggered by clicking any session row in the sidebar list.

- **phx-submit="send_message"** (content: string): Ignores the event if content is blank or streaming is in progress. If no active session exists, calls `Ai.create_chat_session(scope, %{context_type, context_id})` to create one (on failure, flashes an error and stops). Appends an optimistic user message to `messages`, clears `input_value`, and sets `streaming: true`. Calls `Ai.send_chat_message(scope, session_id, content)` which returns `{:ok, pid}` and streams tokens back via `handle_info`. On `:not_found` or `:session_archived`, sets streaming to false and shows an appropriate error flash. Example prompt chips in the empty state also trigger this event with a pre-filled `content` value.

- **phx-change="update_input"** (content: string): Updates `input_value` assign on each keystroke. Does not call any context function. The send button is enabled only when `input_value` is non-blank and streaming is false.

- **phx-click="share_insight"** (message-id: string, optional): Builds a shareable URL for the active session using `MetricFlowWeb.Endpoint.url()`. When a `message-id` is provided the URL includes a `?highlight=` query param. Pushes a `copy_to_clipboard` JS event with the URL and flashes an info message. If no session is active, flashes "No active session to share."

- **handle_info `{:chat_token, token}`**: Appends the token string to `streaming_content`. The streaming message bubble updates in real time as tokens arrive.

- **handle_info `{:chat_complete, meta}`**: Sets `streaming: false` and clears `streaming_content`. Calls `Ai.get_chat_session(scope, session_id)` to refresh the active session and update both `messages` and the matching session in the `sessions` list.

- **handle_info `{:chat_error, reason}`**: Sets `streaming: false`, clears `streaming_content`, and shows an error flash: "The AI encountered an error. Please try again."

## Design

Layout: Full-height two-panel layout inside `Layouts.app`. The outer container fills `calc(100vh - 4rem)` with a flex row and hides overflow, keeping the chat experience fully in-viewport without page scrolling.

Session sidebar (`data-role="session-sidebar"`, `w-64`):
  - On desktop (`sm` and above): always visible as a fixed-width left panel with a right border separator.
  - On mobile: hidden by default; rendered as a full-screen overlay (`fixed inset-0 z-20 bg-base-100`) when `show_sidebar` is true.
  - Sidebar header: "Chats" label (`.text-sm.font-semibold.text-base-content/60.uppercase`) and a "+ New Chat" button (`.btn.btn-primary.btn-xs`, `data-role="new-chat-btn"`).
  - Session list (`data-role="session-list"`, scrollable): empty state text "No chats yet" (`data-role="no-sessions-state"`) when `sessions` is empty. Each session row (`data-role="session-item"`) shows the session title (`data-role="session-title"`), a context type badge (`.badge.badge-ghost.badge-xs`), and a relative timestamp (`data-role="session-updated-at"`, `.text-xs.text-base-content/40`). The active session row uses a slightly highlighted background (`bg-base-content/10`).

Conversation area (`data-role="conversation-area"`, `flex-1 flex flex-col overflow-hidden`):
  - Conversation header: hamburger toggle button visible only on mobile (`data-role="sidebar-toggle"`, `.btn.btn-ghost.btn-sm.sm:hidden`), session title heading (`data-role="session-header"`) with a context type badge when a session is active, or a "New Chat" heading (`data-role="new-chat-header"`) when no session is active.

  - Empty state (`data-role="chat-empty-state"`): shown when `sessions` is empty and no active session. Centered column with H2 "Ask me anything about your data", a subtext paragraph, and three example prompt chips (`.btn.btn-ghost.btn-sm`, `data-role="example-prompt"`) with pre-written questions about revenue, ad platforms, and growth focus.

  - No-session-selected state (`data-role="no-session-selected"`): shown when sessions exist but none is active. Centered text "Select a chat from the sidebar or start a new one." with a "New Chat" button (`.btn.btn-primary.btn-sm`, `data-role="new-chat-prompt-btn"`).

  - Message list (`data-role="message-list"`, `flex-1 overflow-y-auto`): shown when an active session is loaded. Each message row (`data-role="message"`, `data-message-role={role}`):
    - User messages: right-aligned bubble (`data-role="user-message"`, `.bg-primary.text-primary-content`, max 85% width, rounded with a bottom-right notch).
    - Assistant messages: left-aligned bubble (`data-role="assistant-message"`, `.mf-card-cyan`, max 85% width), followed by a "Share" button (`.btn.btn-ghost.btn-xs`, `data-role="share-insight"`).
    - System messages: centered muted text (`data-role="system-message"`, `.text-xs.text-base-content/40`).
    - Streaming waiting indicator (`data-role="streaming-waiting"`): shown when `streaming` is true and `streaming_content` is empty; `.mf-card-cyan` bubble with a `.loading.loading-dots` spinner.
    - Streaming message (`data-role="streaming-message"`): shown when `streaming` is true and `streaming_content` is non-empty; `.mf-card-cyan` bubble displaying accumulated token text with an animated blinking cursor.

  - Message input area (`data-role="message-input-area"`, `border-t`): a form (`phx-submit="send_message"`, `phx-change="update_input"`) containing a resizable textarea (`data-role="message-input"`, `.textarea.textarea-bordered`, disabled when streaming) and a "Send" button (`data-role="send-btn"`, `.btn.btn-primary.btn-sm`, disabled when streaming or input is blank; shows a spinner during streaming). Below the textarea, a context indicator (`data-role="context-indicator"`, `.text-xs.text-base-content/40`) shows the pending context type when set and no session is active.

Components: `.mf-card-cyan`, `.btn`, `.btn-primary`, `.btn-ghost`, `.btn-xs`, `.btn-sm`, `.badge`, `.badge-ghost`, `.badge-xs`, `.badge-sm`, `.textarea`, `.textarea-bordered`, `.loading`, `.loading-dots`, `.loading-spinner`
Responsive: Sidebar collapses to a mobile overlay below `sm` breakpoint; message bubbles shrink from 75% max-width to 85% on mobile; sidebar toggle button visible only on mobile.

