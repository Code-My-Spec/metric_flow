# QA Story Brief

Story 426: Multi-User Account Access
Component: MetricFlowWeb.AccountLive.Members
Route: /accounts/members

## Tool

vibium MCP server

## Auth

Seed data first, then launch the browser and log in via MCP tools:

```bash
./.code_my_spec/qa/scripts/start-qa.sh
```

Then via MCP:

```
mcp__vibium__browser_launch(headless: true)
mcp__vibium__browser_navigate(url: "http://localhost:4070/users/log-in")
mcp__vibium__browser_scroll_into_view(selector: "#login_form_password")
mcp__vibium__browser_fill(selector: "#login_form_password_email", text: "qa@example.com")
mcp__vibium__browser_fill(selector: "#user_password", text: "hello world!")
mcp__vibium__browser_click(selector: "#login_form_password button[name='user[remember_me]']")
mcp__vibium__browser_wait(selector: "body", timeout: 5000)
```

To re-authenticate if the session expires, repeat the MCP login sequence above.

## Seeds

Run the base QA seeds to create the primary owner user and team account:

```bash
mix run priv/repo/qa_seeds.exs
```

This creates:
- Owner user: `qa@example.com` / `hello world!`
- Team account: "QA Test Account" (QA user is the owner)

For scenarios that require a second user (invite, remove, role hierarchy), register one through the UI during the test using a unique email (e.g., `member-426@example.com` / `hello world!`). The second user can be seeded via the registration form at `http://localhost:4070/users/register` before running invite scenarios.

To register a second user for invite testing:

```
mcp__vibium__browser_navigate(url: "http://localhost:4070/users/register")
mcp__vibium__browser_fill(selector: "#registration_form input[name='user[email]']", text: "member-426@example.com")
mcp__vibium__browser_fill(selector: "#registration_form input[name='user[password]']", text: "hello world!")
mcp__vibium__browser_fill(selector: "#registration_form input[name='user[account_name]']", text: "Member Account")
mcp__vibium__browser_click(selector: "#registration_form button[type=submit]")
mcp__vibium__browser_wait(selector: "body", timeout: 5000)
```

Then re-authenticate as the owner before testing the members page:

```
mcp__vibium__browser_delete_cookies()
mcp__vibium__browser_navigate(url: "http://localhost:4070/users/log-in")
mcp__vibium__browser_scroll_into_view(selector: "#login_form_password")
mcp__vibium__browser_fill(selector: "#login_form_password_email", text: "qa@example.com")
mcp__vibium__browser_fill(selector: "#user_password", text: "hello world!")
mcp__vibium__browser_click(selector: "#login_form_password button[name='user[remember_me]']")
mcp__vibium__browser_wait(selector: "body", timeout: 5000)
```

## What To Test

### Scenario 1: Members page loads for authenticated owner (AC: owner can view all users)

1. Navigate to `http://localhost:4070/accounts/members`
2. Capture screenshot: `01_members_page_owner.png`
3. Verify the page heading "Members" is visible
4. Verify the owner's email (`qa@example.com`) appears in the members table
5. Verify the owner's role badge shows "owner"
6. Verify `[data-role="member-row"]` rows are present in the table
7. Verify the "Invite Member" form (`#invite_member_form`) is visible

### Scenario 2: Unauthenticated access redirects (AC: authenticated access required)

```bash
curl -s -o /dev/null -w "%{http_code}" http://localhost:4070/accounts/members
```
Expected: `302` redirect to login

### Scenario 3: Invite an existing user as a member (AC: owner or admin can invite via email)

Prerequisites: Second user `member-426@example.com` must be registered (see Seeds above).

1. Navigate to `http://localhost:4070/accounts/members`
2. Capture screenshot: `02_invite_form_visible.png`
3. Fill the invite form:
   - Email field (`input[name="invitation[email]"]`): `member-426@example.com`
   - Role select (`select[name="invitation[role]"]`): `read_only`
4. Click the "Invite" button
5. Capture screenshot: `03_invite_success.png`
6. Verify "Member invited successfully" flash message appears
7. Verify `member-426@example.com` appears in the members table

### Scenario 4: Invite a non-existent user shows error (AC: owner or admin can invite via email)

1. Navigate to `http://localhost:4070/accounts/members`
2. Fill the invite form with email `nobody-does-not-exist@example.com`, role `read_only`
3. Click "Invite"
4. Capture screenshot: `04_invite_user_not_found_error.png`
5. Verify "User not found" flash error appears

### Scenario 5: Role selector shows all access levels for owner (AC: users can have different access levels; AC: role hierarchy)

1. Navigate to `http://localhost:4070/accounts/members`
2. Capture screenshot: `05_role_options_owner.png`
3. Verify the invite form role select contains: `owner`, `admin`, `account_manager`, `read_only`
4. Verify the row-level role change selects are visible in the Actions column

### Scenario 6: Invite a user as admin role (AC: users can have different access levels)

Prerequisites: Second user `member-426@example.com` must already be a member — if not, invite them first (see Scenario 3), then remove and re-invite as admin, or use a fresh second email.

1. Navigate to `http://localhost:4070/accounts/members`
2. Fill invite form: email `member-426@example.com`, role `admin`
3. Click "Invite"
4. Capture screenshot: `06_invite_as_admin.png`
5. Verify "Member invited successfully" flash appears
6. Verify the `admin` role badge appears next to `member-426@example.com` in the table

### Scenario 7: Owner changes a member's role (AC: owner or admin can modify access levels)

Prerequisites: `member-426@example.com` must already be a `read_only` member.

1. Navigate to `http://localhost:4070/accounts/members`
2. Locate the row for `member-426@example.com`
3. Change the role select dropdown on that row to `admin`
4. Capture screenshot: `07_role_change_select.png`
5. Verify "Role updated" flash message appears
6. Verify `admin` badge now appears for `member-426@example.com`

### Scenario 8: Last owner cannot be demoted or removed (AC: access hierarchy protection)

1. Navigate to `http://localhost:4070/accounts/members` as the sole owner
2. Capture screenshot: `08_last_owner_protection.png`
3. Verify no `[data-role="change-role"]` button appears for the owner's own row (only one owner present)
4. Verify no `[data-role="remove-member"]` button appears for the owner's own row

### Scenario 9: Remove a member from the account (AC: owner or admin can remove users)

Prerequisites: `member-426@example.com` must be a member.

1. Navigate to `http://localhost:4070/accounts/members`
2. Locate the `[data-role="remove-member"]` button for `member-426@example.com`
3. Click the Remove button
4. Capture screenshot: `09_member_removed.png`
5. Verify "Member removed" flash message appears
6. Verify `member-426@example.com` no longer appears in the members table

### Scenario 10: Read-only member cannot see management controls (AC: role hierarchy)

Prerequisites: Log in as `member-426@example.com` (after being invited as `read_only`).

1. Switch user via MCP:
   ```
   mcp__vibium__browser_delete_cookies()
   mcp__vibium__browser_navigate(url: "http://localhost:4070/users/log-in")
   mcp__vibium__browser_scroll_into_view(selector: "#login_form_password")
   mcp__vibium__browser_fill(selector: "#login_form_password_email", text: "member-426@example.com")
   mcp__vibium__browser_fill(selector: "#user_password", text: "hello world!")
   mcp__vibium__browser_click(selector: "#login_form_password button[name='user[remember_me]']")
   mcp__vibium__browser_wait(selector: "body", timeout: 5000)
   ```
2. Navigate to `http://localhost:4070/accounts/members`
3. Capture screenshot: `10_readonly_member_view.png`
4. Verify the `#invite_member_form` is NOT visible on the page
5. Verify no `[data-role="change-role"]` buttons are visible
6. Verify no `[data-role="remove-member"]` buttons are visible

### Scenario 11: Account-level isolation — members of different accounts cannot see each other (AC: same data, account-level isolation)

1. While logged in as `qa@example.com`, visit `http://localhost:4070/accounts/members`
2. Note the members listed (should include `qa@example.com`)
3. Switch to `member-426@example.com` (who has their own separate personal account)
4. Navigate to `http://localhost:4070/accounts/members`
5. Capture screenshot: `11_isolation_separate_account.png`
6. Verify `qa@example.com` does NOT appear in `member-426@example.com`'s members list
7. Verify only `member-426@example.com` (and their own account members) appears

## Result Path

`.code_my_spec/qa/426/result.md`

## Setup Notes

The Members page route is `/accounts/members` (not `/accounts/:id/members`). The LiveView mounts by calling `Accounts.list_accounts/1` and uses the first account returned — for the QA user this will be the team account "QA Test Account" (as the personal account "QA Personal" is also present; the ordering may vary; check which account is shown in the page subtitle).

The invite form uses nested params (`invitation[email]` and `invitation[role]`). When filling the form with MCP tools, target:
- `input[name="invitation[email]"]` for the email field
- `select[name="invitation[role]"]` for the role dropdown

The role change dropdown on each member row fires `phx-change="change_role"` on change — `mcp__vibium__browser_select` should trigger the LiveView update automatically. If the flash message does not appear after selecting a role, try waiting with `mcp__vibium__browser_wait(selector: ".alert")` or `mcp__vibium__browser_wait(selector: "[role=alert]")`.

The owner's own row never shows a remove button (user cannot remove themselves). The last-owner's row also never shows the `[data-role="change-role"]` hidden button (last owner protection).
