# QA Story Brief

Story 432: User or Agency Self-Revokes Access

## Tool

web (vibium MCP browser tools)

## Auth

Run the start-qa script once to seed base data, then log in as the member user to test the revoke access flow.

Seed base data:

```bash
cd /Users/johndavenport/Documents/github/metric_flow
mix run priv/repo/qa_seeds_432.exs
```

Log in as member (the non-owner who can revoke their own access):

```
mcp__vibium__browser_launch(headless: true)
mcp__vibium__browser_navigate(url: "http://localhost:4070/users/log-in")
mcp__vibium__browser_scroll(selector: "#login_form_password")
mcp__vibium__browser_fill(selector: "#login_form_password_email", text: "qa-member@example.com")
mcp__vibium__browser_fill(selector: "#user_password", text: "hello world!")
mcp__vibium__browser_click(selector: "#login_form_password button[name='user[remember_me]']")
mcp__vibium__browser_wait(selector: "body", timeout: 5000)
```

To switch to the owner user:

```
mcp__vibium__browser_delete_cookies()
mcp__vibium__browser_navigate(url: "http://localhost:4070/users/log-in")
mcp__vibium__browser_scroll(selector: "#login_form_password")
mcp__vibium__browser_fill(selector: "#login_form_password_email", text: "qa@example.com")
mcp__vibium__browser_fill(selector: "#user_password", text: "hello world!")
mcp__vibium__browser_click(selector: "#login_form_password button[name='user[remember_me]']")
mcp__vibium__browser_wait(selector: "body", timeout: 5000)
```

## Seeds

```bash
cd /Users/johndavenport/Documents/github/metric_flow
mix run priv/repo/qa_seeds_432.exs
```

This script ensures:
- `qa@example.com` (owner) exists and has a team account "QA Test Account"
- `qa-member@example.com` (member) exists and is a member of that team account

If `qa-member@example.com` already has the `owner` role on the team account (from prior QA runs), the revoke-own-access UI may not appear (owners cannot self-revoke). In that case, you will need to set up a fresh member invitation using the owner user:

1. Log in as `qa@example.com`
2. Navigate to `http://localhost:4070/accounts/invitations`
3. Send an invitation to a fresh email (e.g., `qa-member2@example.com`) with the `read_only` role
4. Check the dev mailbox at `http://localhost:4070/dev/mailbox` for the invitation link
5. Log in as the fresh email user (register first at `/users/register`) and accept the invitation
6. Use that user to test the revoke access flow

## What To Test

### Scenario 1: Non-owner member sees a revoke access button on account settings (AC: User can revoke their own access)

1. Log in as `qa-member@example.com` (or a fresh non-owner member — see Seeds note above)
2. Navigate to `http://localhost:4070/accounts/settings`
3. Take a screenshot of the full page
4. Check for a "Revoke Access", "Leave Account", or similar button on the page
5. Check for an element with `data-role="revoke-own-access"` (expected by BDD spec)
6. Expected: A button to revoke or leave the account is visible to a non-owner member

### Scenario 2: Non-owner member can click the revoke access button (AC: User can revoke their own access)

1. Log in as `qa-member@example.com` (or a fresh non-owner member)
2. Navigate to `http://localhost:4070/accounts/settings`
3. Click the element with `data-role="revoke-own-access"` (or the "Revoke Access"/"Leave Account" button)
4. Take a screenshot after clicking
5. Expected: Either a confirmation dialog appears or a success message ("access has been revoked", "You have left", etc.) is displayed

### Scenario 3: Confirmation prompt warns the action cannot be undone (AC: Confirmation prompt warns that this action cannot be undone)

1. If a confirmation dialog or prompt appeared in Scenario 2, verify it contains a warning that the action is permanent or cannot be undone
2. Take a screenshot of the confirmation prompt
3. Expected: Prompt explicitly warns that the action cannot be undone

### Scenario 4: After revocation, client account is removed from user account list (AC: After revocation, client account is removed from user account list)

1. After successfully revoking access (completing Scenario 2 through confirmation)
2. Navigate to `http://localhost:4070/accounts`
3. Take a screenshot
4. Expected: "QA Test Account" (or the team account that was revoked) no longer appears in the account list

### Scenario 5: Owner cannot self-revoke (AC: Account originator cannot self-revoke and must transfer ownership first)

1. Log in as `qa@example.com` (the owner/originator of the team account)
2. Navigate to `http://localhost:4070/accounts/settings`
3. Take a screenshot
4. Expected: No "Revoke Access" or "Leave Account" button is visible. The page may show "Transfer Ownership" instead, or simply omit the revoke option entirely

### Scenario 6: User cannot re-access account without new invitation (AC: User cannot re-access account without new invitation from client)

1. After revoking access as the member user (Scenario 2-4), while still logged in as the member
2. Try to navigate directly to `http://localhost:4070/accounts/settings` while the active account is the revoked team account
3. Take a screenshot
4. Expected: The revoked account is no longer accessible — user is redirected to `/accounts` or sees an error, not the team account settings

## Setup Notes

The BDD spec for this story tests `/accounts/settings` for an element with `data-role="revoke-own-access"`. Reviewing the current source of `MetricFlowWeb.AccountLive.Settings` (`lib/metric_flow_web/live/account_live/settings.ex`), this element does not exist in the template. The settings page only renders editing/transfer/delete sections for owners and admins, and a read-only view for other roles — there is no revoke-own-access UI.

This means Scenario 1 and 2 are expected to fail (the feature has not been implemented yet). Document what you find: what the settings page actually shows for a non-owner member, and whether any revoke-access functionality exists anywhere in the app.

The dev mailbox at `http://localhost:4070/dev/mailbox` shows all sent emails in the development environment and is useful for retrieving invitation links when setting up fresh member accounts.

## Result Path

`.code_my_spec/qa/432/result.md`
