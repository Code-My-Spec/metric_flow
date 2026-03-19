# QA Result

Story 451: AI Chat for Data Exploration

## Status

fail

## Scenarios

### B1 — Chat entry point on dashboard

pass

Navigated to `http://localhost:4070/dashboard`. The navigation bar contains an `a[href='/chat']` link with text "Chat" (present on both the mobile dropdown and desktop nav). Each metric chart card also renders a `[data-role="ai-info-button"]` button labeled "AI Info". Clicking "AI Info" opens an inline panel on the dashboard page (not a navigation to `/chat`) with text "Metric-specific insights for Clicks based on correlation analysis. Visit AI Insights for detailed recommendations." and a link to `/insights`. The nav "Chat" link is the primary entry point to the AI chat from the dashboard.

Evidence: `.code_my_spec/qa/451/screenshots/b1-dashboard.png`, `.code_my_spec/qa/451/screenshots/b1-ai-info-button-click.png`

### B2 — Chat entry point on correlations page

pass

Navigated to `http://localhost:4070/correlations`. The `a[href='/chat']` nav link with text "Chat" is present.

Evidence: `.code_my_spec/qa/451/screenshots/b2-correlations.png`

### B3 — Chat entry point on insights page

pass

Navigated to `http://localhost:4070/insights`. The `a[href='/chat']` nav link with text "Chat" is present.

Evidence: `.code_my_spec/qa/451/screenshots/b3-insights.png`

### B4 — Navigating to /chat directly

pass

Navigated to `http://localhost:4070/chat`. The page loaded with the two-column layout: session sidebar (`data-role="session-sidebar"`) and conversation area (`data-role="conversation-area"`). With no prior sessions, the empty state (`data-role="chat-empty-state"`) rendered correctly with heading "Ask me anything about your data" and three example prompt chips. After sending a message in this session, the "no-session-selected" state (`data-role="no-session-selected"`) renders correctly when clicking "New Chat" with existing sessions.

Evidence: `.code_my_spec/qa/451/screenshots/b4-chat-direct.png`, `.code_my_spec/qa/451/screenshots/b4-no-session-selected.png`

### B5 — Context indicator on /chat (empty state data awareness)

pass

On `http://localhost:4070/chat` (fresh state), the empty state rendered the heading "Ask me anything about your data" and the subtitle "I have access to your metrics, correlations, and trends. Ask a question in plain language and I'll help you understand what's happening in your business." This constitutes a clear data-context indicator. Three example prompt chips were present: "Why did my revenue drop last week?", "Which ad platform drives the most conversions?", "What should I focus on to grow faster?".

Evidence: `.code_my_spec/qa/451/screenshots/b5-chat-context-indicator.png`

### B6 — Context indicator with correlation context_type param

pass

Navigated to `http://localhost:4070/chat?context_type=correlation`. The `[data-role="context-indicator"]` element was visible and contained the text "Context: Correlations".

Evidence: `.code_my_spec/qa/451/screenshots/b6-context-correlations.png`

### B7 — Context indicator with dashboard context_type param

pass

Navigated to `http://localhost:4070/chat?context_type=dashboard`. The `[data-role="context-indicator"]` element was visible and contained the text "Context: Dashboard".

Evidence: `.code_my_spec/qa/451/screenshots/b7-context-dashboard.png`

### B8 — Chat input is present

pass

On `http://localhost:4070/chat`, the `[data-role="message-input"]` textarea is visible. The `[data-role="send-btn"]` button is visible but disabled until text is typed (correct behavior — disabled when `input_value` is blank). The placeholder text is "Ask a question about your data…".

Evidence: `.code_my_spec/qa/451/screenshots/b8-chat-input-visible.png`

### B9 — Submit a revenue question

partial

Typed "Why did my revenue drop last week?" into `[data-role="message-input"]` and clicked `[data-role="send-btn"]`. The following behaviors were observed and confirmed working:

- The user's message appeared immediately in a `[data-role="user-message"]` bubble (optimistic update confirmed) — text "Why did my revenue drop last week?" visible without page reload
- A chat session was automatically created (title "general chat", context "General") and appeared in `[data-role="session-item"]` in the sidebar
- The URL updated to reflect the active session at `/chat/1`

However, the AI response stream failed. No `[data-role="streaming-waiting"]` or `[data-role="streaming-message"]` appeared. After approximately 3–5 seconds, a flash error was shown: "The AI encountered an error. Please try again." No `[data-role="assistant-message"]` was ever rendered. This error was reproduced consistently across multiple message submissions. The AI stream fails every time in this environment.

Evidence: `.code_my_spec/qa/451/screenshots/b9-revenue-question-typed.png`, `.code_my_spec/qa/451/screenshots/b9-user-message-optimistic.png`, `.code_my_spec/qa/451/screenshots/b9-after-submit-state.png`, `.code_my_spec/qa/451/screenshots/b9-ai-error-flash.png`

### B10 — Metrics question (AC4 — AI has access to all metrics)

partial

Submitted "What are my top metrics this month?" in the existing session. The user message appeared optimistically in the message list (both messages now visible: "Why did my revenue drop last week?" and "What are my top metrics this month?"). AI response did not arrive — same "The AI encountered an error. Please try again." flash shown again. Unable to test whether AI response content references metric-related terms.

Evidence: `.code_my_spec/qa/451/screenshots/b10-metrics-question-submitted.png`, `.code_my_spec/qa/451/screenshots/b10-ai-error-second-message.png`

### B11 — Correlations question (AC4 continued)

skip

Unable to test — AI streaming fails consistently. No AI responses available to inspect.

### B12 — Visualization suggestion question (AC5)

skip

Unable to test — AI streaming fails consistently.

### B13 — Ad spend performance question (AC5 continued)

skip

Unable to test — AI streaming fails consistently.

### B14 — History persists across navigation

pass

After sending the revenue question and having the session created, navigated to `http://localhost:4070/dashboard` and then back to `http://localhost:4070/chat`. The sidebar showed the "general chat" session (timestamp "1 minutes ago"). Clicking the session item navigated to `/chat/1` and the message list loaded with the previously sent message "Why did my revenue drop last week?" — user message persisted correctly in the database across page navigations.

Evidence: `.code_my_spec/qa/451/screenshots/b14-history-after-nav.png`, `.code_my_spec/qa/451/screenshots/b14-session-loaded.png`, `.code_my_spec/qa/451/screenshots/b14-session-restored.png`

### B15 — Session list shows saved sessions with title and timestamp

pass

`[data-role="session-list"]` contained one `[data-role="session-item"]` button. The item included:
- `[data-role="session-title"]` with text "general chat"
- A context badge `.badge.badge-ghost.badge-xs` with text "General"
- `[data-role="session-updated-at"]` with text "1 minutes ago" (relative format)

The active session was highlighted with `bg-base-content/10` class.

Evidence: `.code_my_spec/qa/451/screenshots/b15-session-list-detail.png`

### B16 — Share action visibility (AC7)

fail

Inspected the full page HTML of the chat view with an active session containing a user message. No `[data-role="share-insight"]`, `[data-role="share-button"]`, "Share" button, or "Copy link" link was found anywhere in the page. The message list renders user messages in `[data-role="user-message"]` divs and would render AI messages in `[data-role="assistant-message"]` divs, but no share affordances are attached to either. The spec calls for "User can share chat insights with team members" but no sharing UI is implemented.

Evidence: `.code_my_spec/qa/451/screenshots/b15-session-list-detail.png` (full message list visible, no share UI present)

### B17 — Cross-user chat isolation

pass

Launched a fresh browser session and logged in as `qa-member@example.com`. Navigated to `http://localhost:4070/chat`. The `[data-role="session-sidebar"]` showed the `[data-role="no-sessions-state"]` element with text "No chats yet". None of the `qa@example.com` sessions were visible to the member user. Chat history is correctly isolated per user.

Evidence: `.code_my_spec/qa/451/screenshots/b17-member-chat-page.png`

## Evidence

- `.code_my_spec/qa/451/screenshots/b1-dashboard.png` — Dashboard page with Chat nav link and AI Info buttons on chart cards
- `.code_my_spec/qa/451/screenshots/b1-ai-info-button-click.png` — AI Info panel after clicking the Clicks chart AI Info button
- `.code_my_spec/qa/451/screenshots/b2-correlations.png` — Correlations page with Chat nav link
- `.code_my_spec/qa/451/screenshots/b3-insights.png` — Insights page with Chat nav link
- `.code_my_spec/qa/451/screenshots/b4-chat-direct.png` — /chat empty state with example prompt chips
- `.code_my_spec/qa/451/screenshots/b4-no-session-selected.png` — /chat no-session-selected state after clicking New Chat
- `.code_my_spec/qa/451/screenshots/b5-chat-context-indicator.png` — /chat empty state data-awareness heading and subtitle
- `.code_my_spec/qa/451/screenshots/b6-context-correlations.png` — Context indicator showing "Context: Correlations" with context_type param
- `.code_my_spec/qa/451/screenshots/b7-context-dashboard.png` — Context indicator showing "Context: Dashboard" with context_type param
- `.code_my_spec/qa/451/screenshots/b8-chat-input-visible.png` — Chat input textarea and disabled send button visible
- `.code_my_spec/qa/451/screenshots/b9-revenue-question-typed.png` — Question typed into message input before submit
- `.code_my_spec/qa/451/screenshots/b9-user-message-optimistic.png` — User message bubble appeared immediately after submit
- `.code_my_spec/qa/451/screenshots/b9-after-submit-state.png` — State after submit: user message in list, no AI response
- `.code_my_spec/qa/451/screenshots/b9-ai-error-flash.png` — Full page showing AI error flash message after stream failure
- `.code_my_spec/qa/451/screenshots/b10-metrics-question-submitted.png` — Second message submitted to existing session
- `.code_my_spec/qa/451/screenshots/b10-ai-error-second-message.png` — Full page showing both user messages and AI error flash
- `.code_my_spec/qa/451/screenshots/b14-history-after-nav.png` — Sidebar showing persisted session after navigating away and back
- `.code_my_spec/qa/451/screenshots/b14-session-loaded.png` — Session loaded at /chat/1 URL
- `.code_my_spec/qa/451/screenshots/b14-session-restored.png` — Message list restored after re-clicking session from sidebar
- `.code_my_spec/qa/451/screenshots/b15-session-list-detail.png` — Session item in sidebar with title, badge, and timestamp
- `.code_my_spec/qa/451/screenshots/b17-member-chat-page.png` — Member user's chat page showing empty session list (no owner sessions visible)

## Issues

### AI streaming fails in QA environment — "The AI encountered an error. Please try again."

#### Severity
HIGH

#### Description
Every attempt to send a message via the chat form results in an AI stream error. After submitting a message, the user message is appended optimistically and streaming state begins, but no `[data-role="streaming-waiting"]` or `[data-role="streaming-message"]` ever appears. After approximately 3–5 seconds the LiveView fires the `{:chat_error, _reason}` info handler and the flash "The AI encountered an error. Please try again." is shown.

The `ANTHROPIC_API_KEY` is present in `uat.env` but was not available in the running server's environment during this QA session (confirmed: `echo $ANTHROPIC_API_KEY` returned empty in the shell that ran seeds). The running Phoenix server likely started without the key exported, causing Anthropic API calls to fail authentication.

Reproduction steps:
1. Run `mix run priv/repo/qa_seeds.exs`
2. Start `mix phx.server` without sourcing `uat.env`
3. Log in as `qa@example.com`, navigate to `/chat`
4. Type any message and click Send
5. Observe flash error: "The AI encountered an error. Please try again."

This blocks testing of AC3 (AI response content), AC4 (AI data access), AC5 (AI visualization suggestions), and AC7 (share insights — requires AI responses to be present).

To fix: ensure the dev/QA server is started with `ANTHROPIC_API_KEY` set (e.g., `source uat.env && mix phx.server`). The QA plan and `start-qa.sh` script should be updated to document this requirement.

### Share chat insights UI is not implemented (AC7)

#### Severity
HIGH

#### Description
The acceptance criterion "User can share chat insights with team members" is not implemented. No share affordance (`[data-role="share-insight"]`, `[data-role="share-button"]`, or any "Share" / "Copy link" UI element) exists anywhere in the `/chat` LiveView. The full page HTML was inspected and confirmed to contain no sharing controls on user messages, assistant messages, or anywhere in the conversation area.

URL: `http://localhost:4070/chat/1` (active session with messages)

Expected: Each AI response bubble should have a share button/link per BDD spec criterion 4144.

### AI Info button on dashboard does not navigate to /chat (AC1 mismatch with BDD spec)

#### Severity
MEDIUM

#### Description
The BDD spec for AC1 (criterion 4138) expects that clicking the AI chat button navigates to `/chat` or opens a chat interface. The dashboard's `[data-role="ai-info-button"]` buttons fire `phx-click="show_ai_insights"` which opens a small inline panel on the dashboard itself — the panel links to `/insights` (not `/chat`). The button label is "AI Info" rather than "Open AI Chat" or "AI Chat".

The navigation bar contains a "Chat" link that does navigate to `/chat`, which satisfies the spirit of AC1. However the per-visualization "AI Info" buttons do not open a chat about that metric — they open a static text panel pointing to the insights page.

If the intent of AC1 is for each visualization to have a contextual AI chat entry point (e.g., `?context_type=metric&context_id=...`), the AI Info button does not satisfy that. The BDD spec checks for `data-role="open-ai-chat"`, `data-role="ai-chat-button"`, or `href="/chat"` — none of which match `data-role="ai-info-button"` with `phx-click="show_ai_insights"`.

URL: `http://localhost:4070/dashboard`

### start-qa.sh does not source uat.env — AI key missing during QA runs

#### Severity
MEDIUM

#### Scope
QA

#### Description
The QA start script `.code_my_spec/qa/scripts/start-qa.sh` runs seed scripts but does not source `uat.env` or set the `ANTHROPIC_API_KEY` environment variable. As a result, when the Phoenix server is started separately without the key, all AI streaming calls fail with a generic "The AI encountered an error" flash.

The QA plan at `.code_my_spec/qa/plan.md` does not mention that the server must be started with `ANTHROPIC_API_KEY` set. This is a gap in the QA infrastructure documentation.

Recommended fix: Add a note to `.code_my_spec/qa/plan.md` and to `start-qa.sh` that the server must be started with:

```bash
source uat.env && mix phx.server
```

or that `uat.env` must be exported into the shell before starting the server.
