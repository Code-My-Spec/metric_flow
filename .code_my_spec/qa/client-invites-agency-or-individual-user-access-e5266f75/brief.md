# QA Story Brief

Story 428 — Client Invites Agency or Individual User Access

## Tool

web (Vibium MCP browser automation)

## Auth

Run the base seeds first, then log in as the account owner using the password form.

Seed command:

```bash
mix run priv/repo/qa_seeds.exs
```

Login sequence (MCP tool calls):

```
mcp__vibium__browser_launch(headless: true)
mcp__vibium__browser_navigate(url: "http://localhost:4070/users/log-in")
mcp__vibium__browser_scroll(selector: "#login_form_password")
mcp__vibium__browser_fill(selector: "#login_form_password_email", text: "qa@example.com")
mcp__vibium__browser_fill(selector: "#user_password", text: "hello world!")
mcp__vibium__browser_click(selector: "#login_form_password button[name='user[remember_me]']")
mcp__vibium__browser_wait(selector: "body", timeout: 5000)
```

To test as a second user (the invitee), clear cookies and log in as `qa-member@example.com` / `hello world!`.

The dev mailbox at `http://localhost:4070/dev/mailbox` shows all sent emails — use it to verify invitation emails were delivered and to retrieve invitation tokens from email links.

## Seeds

Run the base QA seeds before testing:

```bash
mix run priv/repo/qa_seeds.exs
```

This creates:
- Owner: `qa@example.com` / `hello world!` (owner of "QA Test Account")
- Member: `qa-member@example.com` / `hello world!` (second user for invitee scenarios)

No additional seeds are needed — all invitation data is created through the UI during testing.

## What To Test

The invitations page is at `/accounts/invitations`. Log in as `qa@example.com` before each scenario group.

### AC1 — Client can send email invitation to any email address

**Scenario A: Invitation form is present on the page**

1. Navigate to `http://localhost:4070/accounts/invitations`
2. Take a screenshot of the page
3. Verify the page title "Invite Members" is displayed
4. Verify the form `#invite_member_form` is present
5. Verify the email input `input[name='invitation[email]']` is present
6. Verify the role select `select[name='invitation[role]']` is present
7. Verify the "Send Invitation" submit button (`data-role="submit-invite"`) is present

Expected: form renders with email field, role select, and submit button.

**Scenario B: Send invitation to an external email address**

1. On `/accounts/invitations`, fill `input[name='invitation[email]']` with `agency@externalfirm.com`
2. Leave the role select at the default (Read Only)
3. Click the "Send Invitation" button
4. Wait for the flash message to appear
5. Take a screenshot
6. Verify a flash or success message containing "Invitation sent" is shown

Expected: success flash like "Invitation sent to agency@externalfirm.com."

**Scenario C: Send invitation to an existing user email address**

1. On `/accounts/invitations`, fill the email field with `qa-member@example.com`
2. Leave role as Read Only
3. Submit the form
4. Take a screenshot
5. Verify a success message is shown and/or `qa-member@example.com` appears in the pending list

Expected: success flash and invitation appears in the pending invitations list.

### AC2 & AC3 — Invitation email contains secure link and invitee receives it

**Scenario: Email is delivered with secure link and 7-day expiry mention**

1. Send an invitation to `qa-member@example.com` from `/accounts/invitations`
2. Navigate to `http://localhost:4070/dev/mailbox`
3. Take a screenshot of the mailbox
4. Verify an email addressed to `qa-member@example.com` appears
5. Open the email and verify:
   - Subject mentions "invited"
   - Body contains the recipient email address
   - Body contains a link path matching `/invitations/`
   - Body mentions "7 days" expiration

Expected: email present in dev mailbox with all required content.

### AC4 — Invitation includes client account name and access level

**Scenario: Email content contains account name and role**

1. Send an invitation to `qa-member@example.com` with role `admin` from `/accounts/invitations`
2. Navigate to `/dev/mailbox` and open the invitation email
3. Take a screenshot
4. Verify the email subject contains the account name (e.g., "QA Test Account")
5. Verify the email body contains the account name
6. Copy the invitation link from the email
7. Navigate to the invitation acceptance link (`/invitations/{token}`)
8. Take a screenshot
9. Verify the acceptance page shows the account name (e.g., "QA Test Account")
10. Verify the acceptance page shows the access level "Admin"

Expected: both email and acceptance page show account name and role.

### AC5 — Client can specify access level: read-only, account manager, or admin

**Scenario: Role select offers all three access levels**

1. Navigate to `/accounts/invitations`
2. Inspect the role select (`select[name='invitation[role]']`)
3. Verify option with `value="read_only"` exists (labeled "Read Only")
4. Verify option with `value="account_manager"` exists (labeled "Account Manager")
5. Verify option with `value="admin"` exists (labeled "Admin")
6. Take a screenshot of the form with the role select visible

Expected: all three role options are present.

**Scenario: Invitation can be sent with each role**

1. Send an invitation to `role-test-readonly@example.com` with role `read_only` — verify success
2. Send an invitation to `role-test-manager@example.com` with role `account_manager` — verify success
3. Send an invitation to `role-test-admin@example.com` with role `admin` — verify success
4. Take a screenshot of the pending invitations list showing all three

Expected: each submission shows a success flash, and all three invitations appear in the pending list with their respective role badges.

### AC6 — Invitation link is single-use and invalidated after acceptance or expiration

**Scenario: Accepted invitation link cannot be reused**

1. Send an invitation to `qa-member@example.com` with role `read_only`
2. Retrieve the invitation link from `/dev/mailbox`
3. Clear browser cookies (`mcp__vibium__browser_delete_cookies()`)
4. Log in as `qa-member@example.com` / `hello world!`
5. Navigate to the invitation link `/invitations/{token}`
6. Take a screenshot of the acceptance page
7. Verify the acceptance page renders (shows "invited" text)
8. Click the accept button (`[data-role='accept-btn']`)
9. Wait for the acceptance to complete
10. Navigate again to the same `/invitations/{token}` URL
11. Take a screenshot
12. Verify the user is redirected with an error flash containing "invalid or has already been used"

Expected: second visit to an accepted invitation link shows error redirect.

**Scenario: Valid pending invitation link shows acceptance page**

1. Send an invitation to `link-test@example.com` with role `read_only`
2. Retrieve the token from `/dev/mailbox`
3. Clear cookies and navigate (unauthenticated) to `/invitations/{token}`
4. Take a screenshot
5. Verify the acceptance page renders with "invited" text visible

Expected: acceptance page loads for a valid pending invitation.

### AC7 — Client can view pending invitations and cancel them

**Scenario: Pending invitations list is visible after sending**

1. Navigate to `/accounts/invitations` (log in as `qa@example.com` if needed)
2. Send an invitation to `pending-view@agency.com` with role `read_only`
3. Take a screenshot of the page after submission
4. Verify `[data-role="pending-invitations"]` section is visible
5. Verify `pending-view@agency.com` appears in the list (`[data-role="invitation-email"]`)
6. Verify the status shows "pending" text somewhere in the row
7. Verify the expiry date is shown ("Expires")
8. Verify a "Cancel" button (`data-role="cancel-invitation"`) is visible for the invitation

Expected: pending invitations section shows the new invitation with email, role badge, sent time, expiry, and cancel button.

**Scenario: Owner can cancel a pending invitation**

1. On `/accounts/invitations`, send an invitation to `tocancel@agency.com` with role `read_only`
2. Verify `tocancel@agency.com` appears in the pending list
3. Click the cancel button for the `tocancel@agency.com` invitation (`[data-role="cancel-invitation"][data-email="tocancel@agency.com"]`)
4. Wait for the page to update
5. Take a screenshot
6. Verify `tocancel@agency.com` no longer appears in `[data-role="pending-invitation-row"]`
7. Verify a flash message appears containing "cancelled"

Expected: invitation is removed from the list and a cancellation flash is shown.

**Scenario: Empty state shown when no invitations are pending**

1. Navigate to `/accounts/invitations` in a fresh state (cancel all existing invitations or use a fresh user)
2. If the pending list is empty, take a screenshot
3. Verify the text "No pending invitations." appears

Expected: empty state message renders when there are no pending invitations.

### AC8 — Client can invite multiple users with different access levels

**Scenario: Multiple invitations appear in the pending list**

1. Navigate to `/accounts/invitations`
2. Send an invitation to `first@agency.com` with role `read_only`
3. Send a second invitation to `second@agency.com` with role `admin`
4. Take a screenshot of the pending list
5. Verify both `first@agency.com` and `second@agency.com` appear in the list
6. Verify the role badges match: "Read Only" for the first, "Admin" for the second
7. Verify the invite form (`#invite_member_form`) is still present and ready for more entries

Expected: both invitations appear simultaneously in the list with correct role labels; form resets and is ready for additional invitations.

## Setup Notes

The source code uses `cancel_invitation` as the event name (not `decline_invitation` as mentioned in the spec). The cancel button is `[data-role="cancel-invitation"]` with `data-email` set to the invitee's email address.

The success flash message reads "Invitation sent to {email}." — the BDD specs check for "Invitation sent" which is a substring of this message, so both are equivalent.

The cancellation flash reads "Invitation to {email} cancelled." — check for "cancelled" as a substring.

The acceptance route `/invitations/:token` is accessible to both authenticated and unauthenticated users. For the single-use test, log in as the invitee before visiting the link so the `[data-role='accept-btn']` button is available.

The `qa@example.com` user owns "QA Test Account". The BDD spec's `SharedGivens` uses "Owner Account" as the expected account name in email subjects — the actual seed account is named "QA Test Account". When verifying email subject/body content for the account name, check for "QA Test Account" in the dev mailbox, not "Owner Account".

## Result Path

`.code_my_spec/qa/428/result.md`
