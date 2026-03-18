# Role change select fires on first user in DOM, not the user with matching hidden input

## Status

resolved

## Severity

medium

## Scope

app

## Description

On the members page ( /accounts/members ), the role change  <select>  elements
use  phx-change="change_role"  with a hidden  <input name="user_id">  inside
each form. When using browser automation (and potentially keyboard navigation),
selecting a value in any role select triggers  change_role  for the user
associated with that select's parent form. However, when using
 tr[data-role="member-row"][data-user-id="2"] select  as the CSS selector, the
first select found (for user_id=2, qa@example.com) was changed instead of the
intended user, accidentally demoting the owner. This is both a UX issue (the form submits on change without confirmation) and a
testability concern. The  phx-change  fires without a separate submit button,
making accidental role changes easy to trigger.

## Source

QA Story 455 — `.code_my_spec/qa/455/result.md`

## Resolution

The role change form used `phx-change="change_role"`, which fired immediately
whenever the select value was changed — without any explicit confirmation. This
made accidental role changes easy to trigger via keyboard navigation or
automation that inadvertently focused the select.

**Fix**: Changed the role change form from `phx-change="change_role"` to
`phx-submit="change_role"`. Added a visible "Change" submit button inside the
form so role changes require an explicit button click to take effect. The hidden
sr-only `[data-role="change-role"]` button with `phx-click="change_role"` is
retained for BDD spex compatibility (spex tests use `render_click` with explicit
role params on that element).

Updated unit tests: the two `render_change` calls in `handle_event change_role`
tests were updated to `render_submit`.

**Files changed:**
- `lib/metric_flow_web/live/account_live/members.ex` — changed form from `phx-change` to `phx-submit`, added visible "Change" submit button
- `test/metric_flow_web/live/account_live/members_test.exs` — updated `render_change` to `render_submit` for role change tests

**Verification:** All 21 members unit tests pass. The role-change BDD spex
(`criterion_3960`) passes using the existing `render_click` path on the
`[data-role="change-role"]` button.
