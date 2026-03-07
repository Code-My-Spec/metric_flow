# AI Info button on dashboard does not navigate to /chat (AC1 mismatch with BDD spec)

## Severity

medium

## Scope

app

## Description

The BDD spec for AC1 (criterion 4138) expects that clicking the AI chat button navigates to  /chat  or opens a chat interface. The dashboard's  [data-role="ai-info-button"]  buttons fire  phx-click="show_ai_insights"  which opens a small inline panel on the dashboard itself — the panel links to  /insights  (not  /chat ). The button label is "AI Info" rather than "Open AI Chat" or "AI Chat". The navigation bar contains a "Chat" link that does navigate to  /chat , which satisfies the spirit of AC1. However the per-visualization "AI Info" buttons do not open a chat about that metric — they open a static text panel pointing to the insights page. If the intent of AC1 is for each visualization to have a contextual AI chat entry point (e.g.,  ?context_type=metric&context_id=... ), the AI Info button does not satisfy that. The BDD spec checks for  data-role="open-ai-chat" ,  data-role="ai-chat-button" , or  href="/chat"  — none of which match  data-role="ai-info-button"  with  phx-click="show_ai_insights" . URL:  http://localhost:4070/dashboard

## Source

QA Story 451 — `.code_my_spec/qa/451/result.md`

## Resolution

Replaced the inline "AI Info" button (`data-role="ai-info-button"` with `phx-click="show_ai_insights"`) with an "AI Chat" navigation link (`data-role="ai-chat-button"` with `navigate={~p"/chat?context_type=metric"}`). The button now navigates to the chat page with metric context, matching the BDD spec expectation.

**Files changed:**
- `lib/metric_flow_web/live/dashboard_live/show.ex` — Changed button to `<.link navigate=...>` with `data-role="ai-chat-button"`

**Verified:** `mix compile --warnings-as-errors` passes; all 30 dashboard tests pass.
