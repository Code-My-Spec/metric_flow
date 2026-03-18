# Invite form role selection ignored — member added as owner instead of selected role

## Status

resolved

## Severity

medium

## Scope

app

## Description

When inviting  qa-member@example.com  to QA Test Account via
 http://localhost:4070/accounts/members , selecting "admin" from the role
dropdown and clicking "Invite" resulted in the member being added with role
"owner" instead of "admin". The flash showed both "Member invited successfully"
and "Cannot demote the last owner" simultaneously, suggesting the invite
system added the user as owner and then attempted an automatic role demotion
that failed. Reproduced: Navigate to  /accounts/members , fill invite form with email
 qa-member@example.com , select role "admin", click "Invite". Check the members
table — user appears as "owner" not "admin".

## Source

QA Story 455 — `.code_my_spec/qa/455/result.md`

## Resolution

The root cause was the dual sr-only input design in the invite form. The form
had hidden sr-only inputs (`name="email"`, `name="role"`) alongside the visible
inputs (`name="invitation[email]"`, `name="invitation[role]"`). Browser automation
would fill the flat sr-only `name="email"` input instead of the visible
`name="invitation[email]"` input, causing `extract_invite_params/1` to fall
through to the flat-params clause where `role` came from the sr-only select
(defaulting to "owner" — the first option for an owner user).

**Fix**: Removed the sr-only duplicate inputs entirely. The invite form now only
contains `invitation[email]` and `invitation[role]`. The `extract_invite_params/1`
function retains its flat-param fallback clause so unit tests that pass flat
params continue to work. Updated unit tests to use nested `invitation:` params
matching the form's actual input names.

**Files changed:**
- `lib/metric_flow_web/live/account_live/members.ex` — removed sr-only duplicate inputs from invite form
- `test/metric_flow_web/live/account_live/members_test.exs` — updated invite tests to use `invitation: %{email: ..., role: ...}` params

**Verification:** All 21 members unit tests pass. The invite-specific BDD spex
(`criterion_3955`) and role-change BDD spex (`criterion_3960`) both pass.
