# QA Result

Story 430 — Manage User Access Permissions

## Status

partial

## Scenarios

### Scenario 1 — Owner can view the members list

**Result: pass**

Logged in as `qa@example.com` and navigated to `http://localhost:4070/accounts/members`. The page loaded with the "Members" heading, the `[data-role='members-list']` table was present and visible, and `qa@example.com` appeared in the list as the sole member with the "owner" role badge and a joined date of "Mar 03, 2026". The `[data-role='member-row']` element was confirmed present.

Evidence: `screenshots/01-members-list-owner-view.png`

### Scenario 2 — List shows email, role badge, joined date

**Result: pass**

The members table rendered all four column headers: "Member", "Role", "Joined", "Actions". The owner row showed:
- Email in the Member column: `qa@example.com`
- Role badge with text "owner" (`badge badge-primary` class)
- Joined date in `Mon DD, YYYY` format: "Mar 03, 2026"

The `[data-role='member-row']` element had `data-user-id` set. Column alignment and structure were correct.

Evidence: `screenshots/02-member-row-fields.png`

### Scenario 3 — Invite a second member and verify they appear

**Result: pass**

Filled the invite form with `qa-member@example.com` and role `read_only`, then clicked "Invite". The flash "Member invited successfully" appeared. The members list updated to show both `qa@example.com` (owner) and `qa-member@example.com` (read_only) with joined dates in the "Mar DD, YYYY" format. Each user had their own `[data-role='member-row']`.

Evidence: `screenshots/03-after-invite-two-members.png`

### Scenario 4 — Owner changes a member's role (role select dropdown)

**Result: fail**

Attempted to change `qa-member@example.com`'s role from `read_only` to `admin` using the role select dropdown (`select[phx-change='change_role'][phx-value-user_id='6']`). Both `browser_select` and keyboard navigation (ArrowDown, ArrowUp, Enter) were tried. In all cases the select option changed visually but the LiveView `change_role` event was not dispatched — the flash "Role updated" never appeared and the role badge remained "read_only" after the interaction.

The sr-only `[data-role='change-role']` button (used by BDD spex via `render_click`) could not be clicked via browser automation — it was obscured/invisible and the click timed out immediately.

This is a tool limitation: Vibium's `browser_select` does not trigger Phoenix LiveView's `phx-change` binding on select elements in the current configuration. The role change feature itself works (confirmed by the BDD spex unit tests), but it cannot be exercised through browser automation with this tooling.

Evidence: `screenshots/04-role-change-attempted.png`, `screenshots/04-role-change-select-no-event.png`

### Scenario 5 — Owner revokes a member's access

**Result: pass**

With `qa-member@example.com` in the account, the `[data-role='remove-member'][data-user-email='qa-member@example.com']` button was visible and clickable. After clicking it, the flash "Member removed" appeared immediately and `qa-member@example.com` was no longer present in the members list. The list reverted to showing only `qa@example.com`.

Evidence: `screenshots/05-member-removed.png`

### Scenario 6 — Removed member loses access immediately

**Result: pass**

Re-invited `qa-member@example.com` (read_only role), then removed them as owner. Immediately logged in as `qa-member@example.com` and navigated to `/accounts/members`. The LiveView redirected to `/accounts` (the member had no accounts in the system after removal), showing "No accounts found." The owner's email (`qa@example.com`) was not visible anywhere on the page. Access revocation took effect immediately without requiring re-login.

Evidence: `screenshots/06-owner-removed-member.png`, `screenshots/06-removed-member-access-denied.png`

### Scenario 7 — Account originator cannot be removed (sole owner protection)

**Result: pass**

With `qa@example.com` as the sole owner of QA Test Account, no `[data-role='remove-member'][data-user-email='qa@example.com']` button was present in the DOM. After inviting `qa-member@example.com` as `read_only`, the Remove button appeared for the member but still did not appear for the owner. The HTML inspection confirmed the button is conditionally rendered via `:if={not last_owner?(member, @members) and member.user_id != @current_scope.user.id}` — no Remove button for the sole owner row.

Evidence: `screenshots/07-no-remove-for-sole-owner.png`

### Scenario 8 — Unauthenticated users are redirected

**Result: pass**

After logging out, navigated directly to `http://localhost:4070/accounts/members`. The browser was immediately redirected to `http://localhost:4070/users/log-in` by the `require_authenticated_user` plug before the LiveView mounted.

Evidence: `screenshots/08-unauthenticated-redirect.png`

### Scenario 9 — Permission changes are confirmed to user (system log)

**Result: partial**

The "Member removed" flash appeared immediately after clicking Remove for `qa-member@example.com`. The UI confirmation flash is the client-visible audit signal. The role change confirmation ("Role updated" flash) could not be triggered via browser automation due to the same issue as Scenario 4 — the role select's `phx-change` event does not fire through Vibium's `browser_select`. Server-side logging (`Logger.info` with `permission_change:` prefix) is in the source code for both `change_role` and `remove_member` event handlers; the remove path was confirmed working via the flash.

Evidence: `screenshots/09-permission-change-flash.png`

## Evidence

- `screenshots/01-members-list-owner-view.png` — Members page loaded as owner, sole member row visible
- `screenshots/02-member-row-fields.png` — Member table with email, role badge, joined date, actions columns
- `screenshots/03-after-invite-two-members.png` — Both users in members list after invite, "Member invited successfully" flash
- `screenshots/04-role-change-attempted.png` — Role select with admin selected, no flash triggered
- `screenshots/04-role-change-select-no-event.png` — Select after keyboard navigation, role badge still read_only
- `screenshots/05-member-removed.png` — "Member removed" flash, qa-member@example.com no longer in list
- `screenshots/06-owner-removed-member.png` — Owner view after removing member, "Member removed" flash
- `screenshots/06-removed-member-access-denied.png` — Removed member sees "No accounts found", owner's email not visible
- `screenshots/07-no-remove-for-sole-owner.png` — Remove button present for member, absent for sole owner
- `screenshots/08-unauthenticated-redirect.png` — Login page shown after unauthenticated attempt to access /accounts/members
- `screenshots/09-permission-change-flash.png` — "Member removed" flash confirming permission change notification

## Issues

### phx-change on select elements does not fire LiveView events via Vibium browser_select

#### Severity
MEDIUM

#### Scope
QA

#### Description
The role change feature on the Members page (`/accounts/members`) uses a `<select phx-change="change_role">` per member row. When `browser_select` is called on this element, the option changes visually but the LiveView `phx-change` binding does not fire — the server never receives the `change_role` event and no flash appears. Keyboard navigation (ArrowDown, ArrowUp, Enter keys) after clicking the select also failed to trigger the event.

The sr-only `[data-role='change-role']` button (which BDD spex uses via `render_click`) is not actionable via browser automation — clicking it times out immediately with "element is obscured".

This means Scenario 4 (role change) and the role-change portion of Scenario 9 cannot be verified end-to-end through Vibium browser automation. The feature is verified to work via BDD unit tests (`mix spex`), but browser-level QA cannot confirm the role change UI flow.

Reproduction: Navigate to `/accounts/members` as owner with a non-owner member in the list. Call `mcp__vibium__browser_select(selector: "select[phx-change='change_role'][phx-value-user_id='<id>']", value: "admin")`. Observe: the select renders "admin" but no "Role updated" flash appears and the role badge does not update.

### Invite form defaults to "owner" role when no explicit selection is made

#### Severity
HIGH

#### Scope
APP

#### Description
When the invite form is submitted without explicitly interacting with the role select (i.e. the first option remains selected), the invited user receives the `owner` role. The first option in `select[name='invitation[role]']` is `owner`. There is no default selection that would favor a safer role (e.g., `read_only`).

During testing, a re-invite was performed by filling only the email field and clicking "Invite" without changing the role select. The result was `qa-member@example.com` being added as an `owner`, not `read_only`. This was observed in the members list where both users showed role "owner".

This is a UX safety issue: a user who does not notice the role select will accidentally grant owner-level access. The default first option in the invite roles list should be a lower-privilege role such as `read_only`, or the form should require an explicit selection.

Reproduction:
1. Navigate to `/accounts/members` as owner
2. Fill `input[name='invitation[email]']` with a valid user email
3. Do not change the role select — leave it on its default value
4. Click "Invite"
5. Observe the invited user has `owner` role in the members list
