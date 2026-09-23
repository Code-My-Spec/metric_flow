# QA Story Brief

Story 451: AI Chat for Data Exploration

## Tool

web (vibium MCP browser tools — `/chat` is a LiveView route)

## Auth

Run the base seed script first, then log in via vibium:

```
mcp__vibium__browser_launch(headless: true)
mcp__vibium__browser_navigate(url: "http://localhost:4070/users/log-in")
mcp__vibium__browser_scroll(selector: "#login_form_password", direction: "down")
mcp__vibium__browser_fill(selector: "#login_form_password_email", text: "qa@example.com")
mcp__vibium__browser_fill(selector: "#user_password", text: "hello world!")
mcp__vibium__browser_click(selector: "#login_form_password button[name='user[remember_me]']")
mcp__vibium__browser_wait(selector: "body", timeout: 5000)
```

For the cross-user history isolation scenario, switch to the member user by clearing cookies and re-logging in:

```
mcp__vibium__browser_navigate(url: "http://localhost:4070/users/log-out")
mcp__vibium__browser_navigate(url: "http://localhost:4070/users/log-in")
mcp__vibium__browser_fill(selector: "#login_form_password_email", text: "qa-member@example.com")
mcp__vibium__browser_fill(selector: "#user_password", text: "hello world!")
mcp__vibium__browser_click(selector: "#login_form_password button[name='user[remember_me]']")
mcp__vibium__browser_wait(selector: "body", timeout: 5000)
```

## Seeds

Run the base seeds before starting. No story-specific AI chat seed script is required — the chat feature creates sessions and messages dynamically as part of testing.

```bash
mix run priv/repo/qa_seeds.exs
```

Credentials produced:
- Owner: `qa@example.com` / `hello world!`
- Member: `qa-member@example.com` / `hello world!`

## Setup Notes

The `/chat` route is at `http://localhost:4070/chat`. The LiveView renders a two-column layout: a session sidebar on the left (`data-role="session-sidebar"`) and a conversation area on the right (`data-role="conversation-area"`).

Key selectors from the source:
- Sidebar new-chat button: `[data-role="new-chat-btn"]`
- Session list: `[data-role="session-list"]`
- Empty state (no sessions): `[data-role="chat-empty-state"]`
- Example prompt chips: `[data-role="example-prompt"]`
- No-session-selected state: `[data-role="no-session-selected"]`
- Conversation header when session active: `[data-role="session-header"]`
- Conversation header when no session: `[data-role="new-chat-header"]`
- Message list: `[data-role="message-list"]`
- User message bubble: `[data-role="user-message"]`
- Assistant message card: `[data-role="assistant-message"]`
- Streaming waiting indicator: `[data-role="streaming-waiting"]`
- Streaming message: `[data-role="streaming-message"]`
- Message textarea: `[data-role="message-input"]` with `name="content"`
- Send button: `[data-role="send-btn"]`
- Context indicator (when pending context set): `[data-role="context-indicator"]`

The form uses `phx-submit="send_message"` with field `name="content"`. Example prompt chips fire `phx-click="send_message"` with `phx-value-content`.

AI responses stream token-by-token. After submitting, wait for `[data-role="streaming-waiting"]` or `[data-role="streaming-message"]` to appear, then wait for it to disappear and for `[data-role="assistant-message"]` to appear when streaming completes.

The share insight feature (`data-role="share-insight"`) is tested only for presence — no share dialog is guaranteed to be fully implemented, so check for the element or any share-related text.

## What To Test

### AC1: User can open AI chat from any report or visualization

- **B1 — Chat entry point on dashboard:** Navigate to `http://localhost:4070/dashboard`. Verify a link or button exists to open AI chat. Look for `[data-role="open-ai-chat"]`, `a[href="/chat"]`, or text containing "Chat". Screenshot the dashboard and note what entry point is present.
- **B2 — Chat entry point on correlations page:** Navigate to `http://localhost:4070/correlations`. Verify a link or button to open AI chat is present. Screenshot.
- **B3 — Chat entry point on insights page:** Navigate to `http://localhost:4070/insights`. Verify a link or button to open AI chat is present. Screenshot.
- **B4 — Navigating to /chat directly:** Navigate to `http://localhost:4070/chat`. Verify the page loads, shows the session sidebar, and shows either the empty state (`data-role="chat-empty-state"`) or the no-session-selected state. Screenshot.

### AC2: Chat context includes relevant data from current view

- **B5 — Context indicator on /chat:** Navigate to `http://localhost:4070/chat`. Verify the page displays context-aware content. Look for the empty-state heading "Ask me anything about your data", the subtitle paragraph referencing metrics/correlations, or a `[data-role="context-indicator"]` element. The empty state heading and subtitle text are strong evidence of data context awareness. Screenshot.
- **B6 — Context indicator with context_type param:** Navigate to `http://localhost:4070/chat?context_type=correlation`. Before sending any message, verify the `[data-role="context-indicator"]` element is visible with text "Context: Correlations". Screenshot.
- **B7 — Context indicator with dashboard context_type:** Navigate to `http://localhost:4070/chat?context_type=dashboard`. Verify the `[data-role="context-indicator"]` shows "Context: Dashboard". Screenshot.

### AC3: User can ask questions like "Why did my revenue drop last week"

- **B8 — Chat input is present:** On `http://localhost:4070/chat`, verify `[data-role="message-input"]` is visible (the textarea).
- **B9 — Submit a revenue question:** Type "Why did my revenue drop last week?" into `[data-role="message-input"]` and click `[data-role="send-btn"]`. Verify:
  - The user's message appears in a `[data-role="user-message"]` bubble immediately after sending (optimistic update)
  - The streaming waiting indicator `[data-role="streaming-waiting"]` appears while the AI responds
  - Eventually `[data-role="assistant-message"]` appears with AI content
  - Screenshot each state: after submit (user message visible), during streaming, and after response arrives.

### AC4: AI has access to all metrics and correlation data to answer

- **B10 — Metrics question:** After B9 completes, submit a second message "What are my top metrics this month?" via the same session. Verify the AI response (when it arrives in `[data-role="assistant-message"]`) references metric-related terms such as "metric", "revenue", "spend", "data", or similar. Screenshot the AI response.
- **B11 — Correlations question:** Submit "What correlations exist in my data?" and verify the AI response references correlation-related terms such as "correlation", "relationship", "trend", or "data". Screenshot.

### AC5: AI can suggest visualizations or reports based on questions

- **B12 — Visualization suggestion question:** Submit "Can you show me a chart of my revenue trends over the past month?" Verify the AI response includes visualization-related language such as "chart", "graph", "visualization", "dashboard", "report", or "view". Screenshot the response.
- **B13 — Ad spend performance question:** Submit "Which metrics should I visualize to understand my ad spend performance?" Verify the AI response references dashboards, reports, or visualizations. Screenshot.

### AC6: Chat history is saved per user

- **B14 — History persists across navigation:** With a session active and messages in it (from earlier scenarios), navigate away to `http://localhost:4070/dashboard`, then return to `http://localhost:4070/chat`. Verify the previous session appears in the sidebar (`[data-role="session-item"]`) and clicking it restores the message list with the previous conversation. Screenshot the restored chat.
- **B15 — Session list shows saved sessions:** Verify the sidebar `[data-role="session-list"]` shows at least one `[data-role="session-item"]` element. Each item should show a title (`[data-role="session-title"]`) and timestamp (`[data-role="session-updated-at"]`). Screenshot.

### AC7: User can share chat insights with team members

- **B16 — Share action visibility:** In an active session with at least one AI response, look for any share-related UI: `[data-role="share-insight"]`, `[data-role="share-button"]`, a button or link with text "Share", or "Copy link". Screenshot the active message list and note what share affordances are present. If no share button is found, record this as an issue.

### Cross-user chat isolation (derived from AC6)

- **B17 — Second user cannot see first user's chat:** Log out as `qa@example.com`, log in as `qa-member@example.com`, navigate to `http://localhost:4070/chat`. Verify the session sidebar is empty or shows only the member user's own sessions — none of the `qa@example.com` session titles should appear. Screenshot the member user's chat page.

## Result Path

`.code_my_spec/qa/451/result.md`
