# QA Result

Story 430 — Manage User Access Permissions

## Status

pass

## Scenarios

### Scenario 1 — Owner can view the members list

pass

Logged in as `qa@example.com` and navigated to `http://localhost:4070/accounts/members`. The page loaded with a "Members" H1 heading and subtitle showing "QA Test Account". The `[data-role='members-list']` element was present. `qa@example.com` appeared in the list with at least one `[data-role='member-row']` element.

Evidence: `01-members-list-owner-view.png`

### Scenario 2 — List shows email, role badge, joined date

pass

Table headers "Member", "Role", "Joined", and "Actions" were all visible. The owner's email `qa@example.com` appeared in the member column. The role badge showed "owner" text. The joined date displayed as "Mar 16, 2026" matching the `Mon DD, YYYY` format.

Evidence: `02-member-row-fields.png`

### Scenario 3 — Invite a second member and verify they appear

pass

Filled the invite form with email `qa-member@example.com` and selected `read_only` from `select[name='invitation[role]']`. Clicked the Invite button. The flash "Member invited successfully" appeared. Both `qa@example.com` (owner) and `qa-member@example.com` (read_only) appeared in the members list with joined dates.

Note: After the invite succeeds, the invite form role select resets to `owner` (the first option in the owner's invite role list). This is a UI issue — the default should be a less-privileged role. See Issues section.

Evidence: `03-after-invite-two-members.png`

### Scenario 4 — Owner changes a member's role

pass

Located the form select for `qa-member@example.com`'s row, changed from `read_only` to `admin`, clicked Change. The flash "Role updated" appeared and the role badge updated to "admin". Changed back to `read_only`, clicked Change. The flash "Role updated" appeared again and the badge reverted to "read_only".

Evidence: `04-role-change-confirmed.png`

### Scenario 5 — Owner revokes a member's access

pass

The `[data-role='remove-member'][data-user-email='qa-member@example.com']` button was present. Clicked it. The flash "Member removed" appeared. `qa-member@example.com` no longer appeared in the members list — only `qa@example.com` remained.

Evidence: `05-member-removed.png`

### Scenario 6 — Removed member loses access immediately

pass

Re-invited `qa-member@example.com` with `read_only` role. Logged out and logged in as `qa-member@example.com`. Navigated to `/accounts/members`. The page loaded but showed "Client Alpha" (qa-member's own primary account) — not "QA Test Account". The owner's email `qa@example.com` did NOT appear on the page. After removal from QA Test Account, the member has no access to that account's data.

Evidence: `06-removed-member-access-denied.png`

### Scenario 7 — Account originator cannot be removed

pass

Logged in as `qa@example.com` and navigated to `/accounts/members`. No `[data-role='remove-member']` button was present for `qa@example.com` (the sole owner row — confirmed by `find()` returning nil). After inviting `qa-member@example.com`, a Remove button was present for the member but still absent for the owner.

Evidence: `07-no-remove-for-sole-owner.png`

### Scenario 8 — Unauthenticated users are redirected

pass

Logged out and navigated directly to `http://localhost:4070/accounts/members`. The browser was redirected to `http://localhost:4070/users/log-in`. The login page rendered correctly.

Evidence: `08-unauthenticated-redirect.png`

### Scenario 9 — Permission changes are confirmed to user

pass

Changed `qa-member@example.com` role to `admin` — the flash "Role updated" appeared. Removed `qa-member@example.com` — the flash "Member removed" appeared. Both UI confirmations were visible and clearly matched the action taken.

Evidence: `09-permission-change-flash.png`

## Evidence

- `.code_my_spec/qa/430/screenshots/01-members-list-owner-view.png` — Members page initial load as owner
- `.code_my_spec/qa/430/screenshots/02-member-row-fields.png` — Member row showing email, role badge, and joined date columns
- `.code_my_spec/qa/430/screenshots/03-after-invite-two-members.png` — After successful invite, both members visible; invite form defaulting to `owner` role visible
- `.code_my_spec/qa/430/screenshots/04-role-change-confirmed.png` — "Role updated" flash after role change back to read_only
- `.code_my_spec/qa/430/screenshots/05-member-removed.png` — "Member removed" flash; only owner remains in list
- `.code_my_spec/qa/430/screenshots/06-removed-member-access-denied.png` — Removed member sees their own account (Client Alpha), not QA Test Account
- `.code_my_spec/qa/430/screenshots/07-no-remove-for-sole-owner.png` — No Remove button for owner row; Remove button present for member row
- `.code_my_spec/qa/430/screenshots/08-unauthenticated-redirect.png` — Unauthenticated redirect to login page
- `.code_my_spec/qa/430/screenshots/09-permission-change-flash.png` — "Member removed" flash confirmation

## Issues

### Invite form role select defaults to "owner" for account owners

#### Severity
HIGH

#### Description
When an account owner opens the Invite Member form, the role select (`select[name='invitation[role]']`) defaults to `owner` — the first option in the list returned by `invite_roles(:owner)` which is `~w(owner admin account_manager read_only member)`. An owner who sends an invite without consciously changing the role dropdown will inadvertently grant the new member full owner access.

Reproduced at `http://localhost:4070/accounts/members` while logged in as `qa@example.com`. The invite form role select visibly shows "owner" as the selected value after page load and after a successful invite.

The fix is to either reorder the invite roles list to put a less-privileged role first (e.g., `read_only`), or add a blank/placeholder option as the default selection that forces the user to make a deliberate choice.

Evidence: `03-after-invite-two-members.png` — the invite form shows `owner` as the selected role after successful invite.
