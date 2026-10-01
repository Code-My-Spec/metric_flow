# Qa Story Brief — Story 28: AI Chat for Data Exploration (retest)

## Tool

web

## Auth

App base URL: http://127.0.0.1:59302

Login page: `http://127.0.0.1:59302/users/log-in` — `#login_form_password` form.
Seeded owner: `qa@example.com` / `hello world!` (active account: QA Test Account).

## Seeds

No new seeds needed. Uses the existing `qa@example.com` / QA Test Account
fixtures and existing visualizations/reports from earlier stories this
session (story 18/19/33 fixtures).

## What To Test

This is a retest of commit `5eb6d6a`, which fixes four issues filed on the
previous (fail) attempt. Two low-severity issues (`ad97105b`, `9e39b656`)
remain open/accepted and are not retested here — unchanged by this commit.

- **58c931b1 (account scoping)**: As `qa@example.com`, switch active account,
  open `/app/chat`, send a message to create a session. Switch to a
  different account the same user belongs to, open `/app/chat` again —
  confirm the session created under the first account does NOT appear in
  the sidebar. Confirm via DB that the new `chat_sessions` row has the
  correct `account_id` (not an arbitrary one).
- **d72edbf4 (shared-link scoping)**: Mark a session shared (`shared: true`),
  note its id. Log in as a user who is NOT a member of that session's
  account and navigate to `/app/chat/<id>` — confirm access is denied
  (not-found/redirect), not granted. Then confirm an actual member of that
  account (or the owner) CAN view it via the share link.
- **4f109159 (real data context)**: Confirm `MetricFlow.Ai.build_data_context/2`
  is actually invoked by code read (done — confirmed in `lib/metric_flow/ai.ex`).
  If Anthropic credits are available, send a real question from a chat
  opened with `context_type=visualization` and verify no "credit balance
  too low" error; if credits are exhausted (seen earlier this session,
  issue `a6d1b2d1`/`35f3e718`), treat this as still-blocked qa-scope and
  verify via code review only, noting the blocker.
- **94686287 (report chat entry point)**: Visit any `/app/reports/:id` page,
  confirm an "AI Chat" link (`data-role="open-ai-chat"`) is present and
  navigates to `/app/chat?context_type=visualization&context_id=<id>`.

## Result Path

.code_my_spec/qa/28/result.md

## Setup Notes

Previous attempt (fail, 2026-10-01T03:22:12Z) filed 5 issues; 4 are now
marked resolved by commit `5eb6d6a`. This pass verifies those 4 live/by
code, and does not re-explore already-accepted low-severity gaps.

### Retest results

- **58c931b1**: confirmed fixed, both sides. A new session created while
  "QA Test Account" (id 21) was active landed in `chat_sessions.account_id=21`
  (correct). After switching to "QA Agency 1101" (id 31), the sidebar only
  showed that account's own session, not the QA Test Account one.
- **d72edbf4**: confirmed fixed. Marked session 10 (account 21) `shared=true`.
  A user with no membership on account 21 hit `/app/chat/10` and got
  "Chat session not found." A real member (`qa-member@example.com`,
  account_manager on account 21) successfully viewed the same shared link.
- **94686287**: confirmed fixed. `/app/reports/21` has a visible "AI Chat"
  link (`data-role="open-ai-chat"`); clicking it navigated to
  `/app/chat?context_type=visualization&context_id=21` as expected. No
  regression on the visualization editor's own chat entry point.
- **4f109159**: confirmed in code — `stream_assistant_response/4` now calls
  `build_data_context/2` and appends it to the system prompt. Could not
  confirm live end-to-end: sending a real question in this environment
  produces no assistant message at all (only the user message persists in
  `chat_messages`), consistent with the pre-existing, already-tracked
  Anthropic-credit/CLI-quota blocker from story 29 (`a6d1b2d1`/`35f3e718`),
  not a regression introduced by this commit.

Also hit and cleared an unrelated pending-migration outage
(`20260930200000_create_account_ownership_transfers`, story 10) blocking the
whole app at session start — filed as qa-scope issue `b0dfac66`.
