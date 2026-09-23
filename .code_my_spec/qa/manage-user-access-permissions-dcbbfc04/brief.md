# QA Story Brief

Story 430 — Manage User Access Permissions

## Tool

web (Vibium MCP browser automation — the Members page is a LiveView behind session auth)

## Auth

Run seeds first (see Seeds section), then launch a browser and log in as the account owner:

```
mcp__vibium__browser_launch(headless: true)
mcp__vibium__browser_navigate(url: "http://localhost:4070/users/log-in")
mcp__vibium__browser_scroll(selector: "#login_form_password")
mcp__vibium__browser_fill(selector: "#login_form_password_email", text: "qa@example.com")
mcp__vibium__browser_fill(selector: "#user_password", text: "hello world!")
mcp__vibium__browser_click(selector: "#login_form_password button[name='user[remember_me]']")
mcp__vibium__browser_wait(selector: "body", timeout: 5000)
```

To switch to the member user (qa-member@example.com) during testing:

```
mcp__vibium__browser_navigate(url: "http://localhost:4070/users/log-out") -- or delete cookies
mcp__vibium__browser_navigate(url: "http://localhost:4070/users/log-in")
mcp__vibium__browser_scroll(selector: "#login_form_password")
mcp__vibium__browser_fill(selector: "#login_form_password_email", text: "qa-member@example.com")
mcp__vibium__browser_fill(selector: "#user_password", text: "hello world!")
mcp__vibium__browser_click(selector: "#login_form_password button[name='user[remember_me]']")
mcp__vibium__browser_wait(selector: "body", timeout: 5000)
```

Credentials:
- Owner: `qa@example.com` / `hello world!`
- Member: `qa-member@example.com` / `hello world!`

## Seeds

Run the base QA seeds from the project root. This is idempotent — safe to run multiple times.

```bash
cd /Users/johndavenport/Documents/github/metric_flow
mix run priv/repo/qa_seeds.exs
```

This creates:
- Owner user: `qa@example.com` (confirmed, password login enabled)
- Member user: `qa-member@example.com` (confirmed, password login enabled)
- Team account: "QA Test Account" — `qa@example.com` is the sole owner

The member user (`qa-member@example.com`) starts with no membership in the QA Test Account. The invite flow is tested live during testing rather than pre-seeded, so you have a clean slate for each scenario.

## What To Test

### Scenario 1 — Owner can view the members list (AC: Client can view list of all users)

1. Log in as `qa@example.com`
2. Navigate to `http://localhost:4070/accounts/members`
3. Verify the page loads with a "Members" heading
4. Verify a members table is present (`[data-role='members-list']`)
5. Verify the owner's own email (`qa@example.com`) appears in the list
6. Verify at least one `[data-role='member-row']` element exists
7. Take screenshot: `01-members-list-owner-view.png`

### Scenario 2 — List shows email, role badge, joined date (AC: List shows user/agency name, access level, date granted)

1. Log in as `qa@example.com`, navigate to `/accounts/members`
2. Verify the table headers: "Member", "Role", "Joined", "Actions" are all visible
3. Verify the owner's email appears in the member column
4. Verify a role badge with text "owner" is shown for the owner row
5. Verify a date in format `Mon DD, YYYY` (e.g. "Mar 05, 2026") appears in the Joined column
6. Take screenshot: `02-member-row-fields.png`

### Scenario 3 — Invite a second member and verify they appear (AC: Client can view list)

1. While on `/accounts/members` as the owner, fill the invite form:
   - Email: `qa-member@example.com`
   - Role: `read_only` (select from `select[name='invitation[role]']`)
2. Click the "Invite" button (submit `#invite_member_form`)
3. Wait for the flash: "Member invited successfully"
4. Verify both `qa@example.com` and `qa-member@example.com` appear in the members list
5. Verify the invited member row shows role "read_only" and a joined date
6. Take screenshot: `03-after-invite-two-members.png`

### Scenario 4 — Owner changes a member's role (AC: Client can modify access level)

1. With both users in the account (invite first if needed — see Scenario 3)
2. Navigate to `/accounts/members` as owner
3. Find the member row for `qa-member@example.com`
4. Change the role using the role select dropdown (`select[phx-change='change_role']` for that row) from `read_only` to `admin`
5. Wait for the flash: "Role updated"
6. Verify the member row now shows "admin" badge for that user
7. Change the role back to `read_only` (downgrade test)
8. Wait for flash: "Role updated"
9. Verify the row now shows "read_only"
10. Take screenshot: `04-role-change-confirmed.png`

### Scenario 5 — Owner revokes a member's access (AC: Client can revoke access; removed from list)

1. With `qa-member@example.com` in the account, navigate to `/accounts/members` as owner
2. Verify the Remove button exists for `qa-member@example.com`: `[data-role='remove-member'][data-user-email='qa-member@example.com']`
3. Click the Remove button for `qa-member@example.com`
4. Wait for the flash: "Member removed"
5. Verify `qa-member@example.com` no longer appears in the members list
6. Take screenshot: `05-member-removed.png`

### Scenario 6 — Removed member loses access immediately (AC: When access is revoked, user immediately loses ability to view client data)

1. Re-invite `qa-member@example.com` with `read_only` role so they are in the account
2. Log in as `qa-member@example.com` in a second browser session (delete cookies and re-login)
3. Navigate to `/accounts/members` as the member user — note they can access the page
4. Switch back to the owner session and remove `qa-member@example.com`
5. As `qa-member@example.com`, navigate to `/accounts/members` again immediately
6. Verify the owner's email (`qa@example.com`) is NOT visible on the page (member can only see their own personal account data), OR the page redirects — either is acceptable
7. Take screenshot: `06-removed-member-access-denied.png`

### Scenario 7 — Account originator cannot be removed (AC: Account originator cannot have access revoked)

1. Log in as `qa@example.com`, navigate to `/accounts/members`
2. When `qa@example.com` is the ONLY owner, verify there is NO `[data-role='remove-member']` button for the owner's own row
3. Invite `qa-member@example.com` as a member
4. Verify a Remove button IS present for `qa-member@example.com`
5. Verify NO Remove button exists for `qa@example.com` (the sole owner)
6. Take screenshot: `07-no-remove-for-sole-owner.png`

### Scenario 8 — Unauthenticated users are redirected

1. Without logging in (or after deleting cookies), attempt to navigate to `http://localhost:4070/accounts/members`
2. Verify you are redirected to `/users/log-in`
3. Take screenshot: `08-unauthenticated-redirect.png`

### Scenario 9 — Permission changes are confirmed to user (AC: System logs all permission changes)

1. Log in as owner, invite `qa-member@example.com` with `read_only`
2. Change role to `admin` — verify flash "Role updated" appears
3. Remove `qa-member@example.com` — verify flash "Member removed" appears
4. Note: The source code logs changes via `Logger.info` with `permission_change:` prefix, timestamp, and acting user's email. This is the server-side audit log. The UI confirmation flash is the client-visible evidence.
5. Take screenshot: `09-permission-change-flash.png`

## Setup Notes

The Members page is at `/accounts/members` and is implemented as `MetricFlowWeb.AccountLive.Members`. It mounts using the first account from `Accounts.list_accounts(scope)`. The seed script creates "QA Test Account" with `qa@example.com` as the owner.

The invite form uses nested params: `invitation[email]` and `invitation[role]`. CSS selectors for the visible form fields:
- Email input: `input[name='invitation[email]']`
- Role select: `select[name='invitation[role]']`
- Submit button: `#invite_member_form button[type='submit']`

Role values in the select: `owner`, `admin`, `account_manager`, `read_only`, `member` (where `member` maps to `read_only`).

The role change select is per-row: `select[phx-change='change_role'][phx-value-user_id='<id>']`. The hidden change-role button used by BDD spex (`[data-role='change-role']`) is `sr-only` (screen-reader only) and may not be interactable via browser automation — use the visible role select dropdown instead.

The Remove button selector is `[data-role='remove-member'][data-user-email='<email>']`. It is only rendered for non-last-owner rows and for members other than the current logged-in user.

## Result Path

`.code_my_spec/qa/430/result.md`
