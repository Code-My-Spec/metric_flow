# QA Story Brief — Story 429: Agency or User Accepts Client Invitation

## Tool

web (vibium MCP browser tools — the acceptance page is a LiveView)

## Auth

Run the base seed script first, then log in as the QA owner or member as needed.

Login as owner (qa@example.com):
```
mcp__vibium__browser_navigate(url: "http://localhost:4070/users/log-in")
mcp__vibium__browser_scroll(selector: "#login_form_password")
mcp__vibium__browser_fill(selector: "#login_form_password_email", text: "qa@example.com")
mcp__vibium__browser_fill(selector: "#user_password", text: "hello world!")
mcp__vibium__browser_click(selector: "#login_form_password button[name='user[remember_me]']")
mcp__vibium__browser_wait(selector: "body", timeout: 5000)
```

Switch to member (qa-member@example.com) by clearing cookies and re-logging in:
```
mcp__vibium__browser_delete_cookies()
mcp__vibium__browser_navigate(url: "http://localhost:4070/users/log-in")
mcp__vibium__browser_scroll(selector: "#login_form_password")
mcp__vibium__browser_fill(selector: "#login_form_password_email", text: "qa-member@example.com")
mcp__vibium__browser_fill(selector: "#user_password", text: "hello world!")
mcp__vibium__browser_click(selector: "#login_form_password button[name='user[remember_me]']")
mcp__vibium__browser_wait(selector: "body", timeout: 5000)
```

## Seeds

Run in order:

```bash
# Base seeds — creates qa@example.com, qa-member@example.com, and "QA Test Account"
mix run priv/repo/qa_seeds.exs

# Story 429 seeds — creates invitation tokens and prints acceptance URLs
mix run priv/repo/qa_seeds_429.exs
```

The seed script prints the actual encoded tokens and full URLs to use in testing. Copy the tokens from the script output before starting browser tests.

Expected output from qa_seeds_429.exs:
- A pending invitation token (e.g. `0bvAU2LZRCNRsNfWhwZl7ryK8eBMwTd6k10MJOPZ_Ow`)
- An already-accepted invitation token
- Full acceptance URLs for both

The seed script is idempotent for the accepted invitation, but deletes and recreates the pending invitation each run (to guarantee a fresh token). Re-run it to get new tokens if needed.

**Note on member pre-existing access:** The base seeds add qa-member@example.com as a member of "QA Test Account" during prior QA runs. If the member is already a member, accepting the pending invitation will show "You already have access to this account." and redirect to `/accounts`. This tests the `:already_member` path. Create a fresh user with a different email if you need to test a clean first-time acceptance.

## What To Test

Replace `{PENDING_TOKEN}` and `{ACCEPTED_TOKEN}` with the actual tokens from the seed output.

### B1 — Acceptance page renders for a logged-in user (AC: User clicks invitation link and is taken to acceptance page)

1. Log in as qa@example.com
2. Navigate to `http://localhost:4070/invitations/{PENDING_TOKEN}`
3. Verify the page shows "You've been invited" as the heading
4. Verify the page shows the account name "QA Test Account"
5. Verify the page shows the inviting user's email (qa@example.com)
6. Verify the page shows the role label "Account Manager"
7. Verify an "Accept Invitation" button is present (`[data-role="accept-btn"]`)
8. Verify a "Decline" button is present (`[data-role="decline-btn"]`)
9. Screenshot: acceptance page while logged in

### B2 — Acceptance page renders for an unauthenticated user, with login/register prompts (AC: If not logged in, user is prompted to log in or register)

1. Clear cookies (log out)
2. Navigate to `http://localhost:4070/invitations/{PENDING_TOKEN}` without logging in
3. Verify the page renders (not a redirect) and shows "You've been invited"
4. Verify "Log In to Accept" button is present (`[data-role="log-in-btn"]`)
5. Verify "Create an Account" button is present (`[data-role="register-btn"]`)
6. Verify no "Accept Invitation" button is shown (only shown to authenticated users)
7. Screenshot: acceptance page while unauthenticated

### B3 — Log in button redirects to login with return_to (AC: If not logged in, user is prompted to log in or register)

1. While on the acceptance page as an unauthenticated user (from B2)
2. Click "Log In to Accept"
3. Verify the browser navigates to `/users/log-in` with a `return_to` query param pointing back to the invitation URL
4. Screenshot: login page with return_to param

### B4 — Register button redirects to registration with return_to (AC: If not logged in, user is prompted to log in or register)

1. Navigate back to `http://localhost:4070/invitations/{PENDING_TOKEN}` without logging in
2. Click "Create an Account"
3. Verify the browser navigates to `/users/register` with a `return_to` query param pointing back to the invitation URL
4. Screenshot: registration page with return_to param

### B5 — Accepting the invitation grants access and redirects (AC: Upon acceptance, user account is granted specified access level to client account)

1. Log in as qa-member@example.com
2. Navigate to `http://localhost:4070/invitations/{PENDING_TOKEN}`
3. Click "Accept Invitation" (`[data-role="accept-btn"]`)
4. Verify the browser redirects to `/accounts`
5. Verify a flash message is shown — either:
   - "You now have access to QA Test Account." (if member was not already a member), OR
   - "You already have access to this account." (if member was already a member from prior runs)
6. Screenshot: accounts page after accepting

### B6 — Client account appears in the account switcher or list after acceptance (AC: User sees client account added to their account switcher or list)

1. After B5 (while logged in as qa-member@example.com on `/accounts`)
2. Verify "QA Test Account" appears in the accounts list
3. Screenshot: accounts list showing the client account

### B7 — Invalid/not-found token shows an error and redirects (AC: Expired invitations show clear error message; Already-accepted invitations cannot be reused)

**Already-accepted token:**
1. Log in as qa@example.com
2. Navigate to `http://localhost:4070/invitations/{ACCEPTED_TOKEN}`
3. Verify the browser redirects away (to `/`) — the acceptance page is not rendered
4. Verify a flash error message is shown: "This invitation link is invalid or has already been used."
5. Screenshot: homepage with flash error after accepted token

**Non-existent token:**
1. Navigate to `http://localhost:4070/invitations/totally-invalid-token-xyz`
2. Verify the browser redirects to `/`
3. Verify a flash error message is shown: "This invitation link is invalid or has already been used."
4. Screenshot: flash error for nonexistent token

### B8 — Declining an invitation (bonus — from spec)

1. Create a new pending invitation by re-running `mix run priv/repo/qa_seeds_429.exs` to get a fresh token
2. Log in as qa-member@example.com
3. Navigate to `http://localhost:4070/invitations/{FRESH_PENDING_TOKEN}`
4. Click the "Decline" button (`[data-role="decline-btn"]`)
5. Verify the browser redirects to `/`
6. Verify a flash message "Invitation declined." is shown
7. Screenshot: after declining

### B9 — Expired invitation behavior (for documentation)

Note: The app does not have a UI path to set a specific expiry date in seeds. Expired invitations
redirect to `/` with "This invitation has expired." Verify this by checking the source behavior —
the `mount/3` callback in `InvitationLive.Accept` redirects on `{:error, :expired}` and
`{:error, :not_found}` rather than rendering the page. If a backdated invitation is needed,
create it via IEx or a custom seed script.

## Setup Notes

**Route:** The invitation acceptance LiveView is at `/invitations/:token` — there is no `/accept` suffix. The BDD spec files reference `/invitations/:token/accept` but the actual route is `/invitations/:token`.

**Error handling is redirect-based:** Invalid, expired, and already-used invitation tokens do NOT render an error on the acceptance page. Instead, the `mount/3` callback redirects to `/` with a flash error. The acceptance page is only rendered when a valid pending invitation is found.

**Agency team access (AC 7):** The acceptance criteria states "if invitee is part of an agency, entire agency team gets access." The current implementation grants access to the individual user only (`accept_invitation/2` adds the accepting user as an `AccountMember`). This criterion is architecture-level behavior — there is no additional visual cue to test in the browser beyond the accepting user seeing the account added to their list.

**Token lifecycle:** Tokens are single-use. Once a pending invitation is accepted or declined, its status changes and the token becomes invalid (returns `{:error, :not_found}`). Re-run `mix run priv/repo/qa_seeds_429.exs` to generate fresh tokens between test runs.

## Result Path

`.code_my_spec/qa/429/result.md`
