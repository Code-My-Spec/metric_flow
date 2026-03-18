# Admin invite form shows "admin" role option but backend rejects it

## Status

resolved

## Severity

medium

## Scope

app

## Description

When a user with the  admin  role visits  /accounts/members , the invite form's role select ( select[name="invitation[role]"] ) shows  admin ,  account_manager ,  read_only , and  member  as options. When the admin selects  admin  and submits the invite, the backend returns "You are not authorized to invite members". The backend authorization is correct per  Authorization.can?/3 : admins cannot assign the  admin  role (only  account_manager  and below). But the UI invite form presents  admin  as a valid choice for admin users via  @admin_invite_roles ~w(admin account_manager read_only member)  in  members.ex . The form should only show the roles the current user is authorized to assign ( account_manager ,  read_only ,  member  for admin users). Reproduction steps: Log in as a user who is  admin  (not  owner ) on an account Navigate to  /accounts/members Fill the invite form with any existing user's email and select role  admin Click "Invite" Observe: "You are not authorized to invite members" flash despite the form offering  admin  as an option

## Source

QA Story 426 — `.code_my_spec/qa/426/result.md`

## Resolution

Removed `"admin"` from the `@admin_invite_roles` module attribute in `members.ex`. The attribute was changed from `~w(admin account_manager read_only member)` to `~w(account_manager read_only member)`. Admin users can now only see and select the roles they are actually authorized to assign, eliminating the confusing UX of the form offering an option that the backend will always reject.

**Files changed:**
- `lib/metric_flow_web/live/account_live/members.ex` — removed `"admin"` from `@admin_invite_roles`

**Verification:** All 21 tests in `members_test.exs` pass; full suite of 2561 tests passes with 0 failures.
