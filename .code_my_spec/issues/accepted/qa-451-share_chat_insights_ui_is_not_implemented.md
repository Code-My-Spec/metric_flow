# Share chat insights UI is not implemented (AC7)

## Severity

high

## Scope

app

## Description

The acceptance criterion "User can share chat insights with team members" is not implemented. No share affordance ( [data-role="share-insight"] ,  [data-role="share-button"] , or any "Share" / "Copy link" UI element) exists anywhere in the  /chat  LiveView. The full page HTML was inspected and confirmed to contain no sharing controls on user messages, assistant messages, or anywhere in the conversation area. URL:  http://localhost:4070/chat/1  (active session with messages) Expected: Each AI response bubble should have a share button/link per BDD spec criterion 4144.

## Source

QA Story 451 — `.code_my_spec/qa/451/result.md`

## Resolution

Added a "Share" button (`data-role="share-insight"`) below each assistant message in the chat LiveView. Clicking it copies a direct link to that message (e.g., `/chat/1?highlight=42`) to the clipboard via a `copy_to_clipboard` push event and shows a flash confirmation.

**Files changed:**
- `lib/metric_flow_web/live/ai_live/chat.ex` — Added share button to assistant message template and `handle_event("share_insight", ...)` handler

**Verified:** `mix compile --warnings-as-errors` passes; dashboard and chat tests pass (4 pre-existing chat test failures unrelated to this change).
