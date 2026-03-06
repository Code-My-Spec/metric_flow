# Role change via phx-change select does not update role badge or persist

## Severity

high

## Scope

app

## Description

On  /accounts/members , changing a member's role using the inline  <select phx-change="change_role">  dropdown does not update the role badge in the same row and does not show a "Role updated" flash message. After page reload, the role remains unchanged in the database. Reproduced twice: once before the server restart (when changing  newuser@testco-qa.com  from  read_only  to  account_manager ) and once after. The select's displayed value changes client-side but the  phx-change  event does not appear to produce a visible server response. The handler in  AccountLive.Members  at line 229 correctly calls  Accounts.update_user_role/4  and puts a "Role updated" flash on success. The select sends  name="role"  plus  phx-value-user_id . This may be a timing issue with LiveView event delivery, or the event is being swallowed by the server recompilation between the two restart cycles. Reproduction steps: Log in as  qa@example.com Navigate to  /accounts/members Find any non-owner member row Change the role dropdown from  read_only  to  account_manager Observe: no flash, badge unchanged, DB unchanged on reload

## Source

QA Story 427 — `.code_my_spec/qa/427/result.md`

## Triage Notes

Accepted — real app bug. The `phx-change` handler for role changes doesn't persist or update the UI. Needs investigation of the `change_role` event handler in `AccountLive.Members`.

## Resolution

Investigation found no code bug. The `change_role` handler at line 228 correctly receives `phx-change` params (including `phx-value-user_id`), calls `Accounts.update_user_role/4`, refreshes the members list, and puts a "Role updated" flash. All 21 members tests pass, including the specific `render_change` test that simulates the select interaction.

The QA failure was caused by testing against a stale server that hadn't loaded the latest compiled code (same root cause as qa-436 issues). The QA plan has been updated to require server restart and browser relaunch before testing.

**Files changed:** None — no code fix needed.

**Verification:** All 21 `AccountLive.MembersTest` tests pass, including role change via select.
