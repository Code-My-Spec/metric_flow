# Role change via inline select still drops LiveView connection (regression of qa-427)

## Status

resolved

## Severity

high

## Scope

app

## Description

Selecting a new role from the inline  <select phx-change="change_role">  in the Actions column on  /accounts/members  causes the LiveView connection to drop with "We can't find the internet / Attempting to reconnect" errors. After page reload, the role is unchanged in the database. Reproduced twice during this test run. Issue qa-427 was previously marked as resolved with the fix "Wrapped role select in a form with hidden user_id input". The fix is present in the code (the select IS inside a  <form phx-change="change_role">  with a hidden  <input name="user_id"> ). However, both the  <form>  AND the  <select>  element have  phx-change="change_role"  attributes. When the select value changes, both events fire. This double-firing may be causing the LiveView connection to behave unexpectedly. The select-level  phx-change  fires first without form data (no user_id), hitting the handler which fails to match params, and the connection is disrupted before the form-level event delivers user_id. Reproduction steps: Log in as any admin or owner user Navigate to  /accounts/members Find any non-owner member row Change the role dropdown from the current value to a different value Observe: LiveView shows reconnection errors, no "Role updated" flash, role unchanged on reload

## Source

QA Story 426 — `.code_my_spec/qa/426/result.md`

## Resolution

Removed the form wrapper entirely and moved `phx-change="change_role"` directly onto the `<select>` element with a `phx-value-user_id={member.user_id}` attribute. When `phx-change` fires on the select, Phoenix LiveView merges `phx-value-*` attributes into the event params alongside the element's value, so the handler receives both `role` and `user_id` from a single event with no double-firing.

The previous attempt (form with hidden input + select-level phx-change) caused two events to fire on every change: the select fired first with only `%{"role" => ...}` (no `user_id`), which failed to match the handler's `%{"role" => role, "user_id" => user_id}` pattern and crashed the process, dropping the LiveView WebSocket connection.

**Files changed:**
- `lib/metric_flow_web/live/account_live/members.ex` — replaced form+hidden-input pattern with a bare select using `phx-value-user_id`

**Verification:** All 21 tests in `members_test.exs` pass; full suite of 2561 tests passes with 0 failures.
