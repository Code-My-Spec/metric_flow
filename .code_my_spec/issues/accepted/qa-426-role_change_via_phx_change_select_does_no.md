# Role change via phx-change select does not update role or show flash

## Status

resolved

## Severity

high

## Scope

app

## Description

On  /accounts/members , changing a member's role using the inline  <select phx-change="change_role" phx-value-user_id={member.user_id}>  dropdown does not produce a server response. No "Role updated" flash message appears and the role badge remains unchanged. After navigating away and back, the DB value is also unchanged. The issue was previously filed as qa-427 and marked resolved with the note "Wrapped role select in a form with hidden user_id input so phx-change sends the user_id in form data." However, the current implementation in  lib/metric_flow_web/live/account_live/members.ex  lines 92-110 does not use a form wrapper — it uses  phx-value-user_id  on the select element directly. Phoenix LiveView  phx-change  events do not include  phx-value-*  attributes in params — only  phx-click  events merge  phx-value-*  into params. As a result, the  change_role  handler receives  %{"role" => "..."}  without  user_id , causing it to fail silently or hit the wrong clause. Reproduction: Log in as any admin or owner Navigate to  /accounts/members Change any non-owner member's role in the dropdown Observe: no flash message, no badge update, no DB change on reload

## Source

QA Story 426 — `.code_my_spec/qa/426/result.md`

## Resolution

Wrapped the role `<select>` in a `<form phx-change="change_role">` with a hidden `<input type="hidden" name="user_id" value={member.user_id} />`. Phoenix LiveView `phx-change` events send all form inputs as params, so the handler now receives both `role` and `user_id` correctly. The `phx-value-user_id` attribute was removed from the select since it has no effect on `phx-change` events (it only merges into `phx-click` params).

The hidden `[data-role="change-role"]` button was preserved unchanged — it uses `phx-click` which does correctly pass `phx-value-user_id`, so BDD spex tests that use `render_click` on that button continue to work.

**Files changed:**
- `lib/metric_flow_web/live/account_live/members.ex` — replaced bare `<select phx-change>` with `<form phx-change>` wrapping a hidden `user_id` input and the role select
- `test/metric_flow_web/live/account_live/members_test.exs` — updated two `change_role` tests to target `form` instead of `select` for `render_change` calls, matching the new template structure

**Verification:** `mix test` — 2561 tests, 0 failures.
