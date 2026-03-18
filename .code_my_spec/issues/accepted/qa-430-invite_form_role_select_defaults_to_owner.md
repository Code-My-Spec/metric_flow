# Invite form role select defaults to "owner" for account owners

## Status

resolved

## Severity

high

## Scope

app

## Description

When an account owner opens the Invite Member form, the role select ( select[name='invitation[role]'] ) defaults to  owner  — the first option in the list returned by  invite_roles(:owner)  which is  ~w(owner admin account_manager read_only member) . An owner who sends an invite without consciously changing the role dropdown will inadvertently grant the new member full owner access. Reproduced at  http://localhost:4070/accounts/members  while logged in as  qa@example.com . The invite form role select visibly shows "owner" as the selected value after page load and after a successful invite. The fix is to either reorder the invite roles list to put a less-privileged role first (e.g.,  read_only ), or add a blank/placeholder option as the default selection that forces the user to make a deliberate choice. Evidence:  03-after-invite-two-members.png  — the invite form shows  owner  as the selected role after successful invite.

## Source

QA Story 430 — `.code_my_spec/qa/430/result.md`

## Resolution

Reordered `@owner_invite_roles` in `members.ex` from `~w(owner admin account_manager read_only member)` to `~w(member read_only account_manager admin owner)`, so the HTML `<select>` defaults to "member" (least privilege) instead of "owner".

**Files changed:**
- `lib/metric_flow_web/live/account_live/members.ex` — reordered `@owner_invite_roles` list

**Verification:** All 21 members tests pass.
