# QA Story Brief — 455: Account Deletion (Owner Only)

## Tool

web (vibium MCP browser automation — all routes are LiveView behind `:browser` pipeline + `require_authenticated_user`)

## Auth

Run seeds first, then log in via vibium MCP tools:

```
# 1. Seed data (run once in terminal)
cd /Users/johndavenport/Documents/github/metric_flow
./.code_my_spec/qa/scripts/start-qa.sh

# 2. Launch browser
mcp__vibium__browser_launch(headless: true)

# 3. Log in as owner (qa@example.com)
mcp__vibium__browser_navigate(url: "http://localhost:4070/users/log-in")
mcp__vibium__browser_scroll_into_view(selector: "#login_form_password")
mcp__vibium__browser_fill(selector: "#login_form_password_email", text: "qa@example.com")
mcp__vibium__browser_fill(selector: "#user_password", text: "hello world!")
mcp__vibium__browser_click(selector: "#login_form_password button[name='user[remember_me]']")
mcp__vibium__browser_wait(selector: "body", timeout: 5000)
```

To switch to the member user mid-session:
```
mcp__vibium__browser_delete_cookies()
mcp__vibium__browser_navigate(url: "http://localhost:4070/users/log-in")
mcp__vibium__browser_scroll_into_view(selector: "#login_form_password")
mcp__vibium__browser_fill(selector: "#login_form_password_email", text: "qa-member@example.com")
mcp__vibium__browser_fill(selector: "#user_password", text: "hello world!")
mcp__vibium__browser_click(selector: "#login_form_password button[name='user[remember_me]']")
mcp__vibium__browser_wait(selector: "body", timeout: 5000)
```

Credentials:
- Owner: `qa@example.com` / `hello world!`
- Member: `qa-member@example.com` / `hello world!`
- App: http://localhost:4070

## Seeds

```bash
cd /Users/johndavenport/Documents/github/metric_flow
mix run priv/repo/qa_seeds.exs
```

This creates:
- Owner user `qa@example.com` (owner of team account "QA Test Account")
- Member user `qa-member@example.com` (not yet a member of the team account)

The member user must be invited to the team account via the Members page before testing role-based access. Do this in-browser as part of the relevant scenarios (see scenario 4 below).

Note: The seeded team account is named **"QA Test Account"**. Use this exact name when typing the confirmation in the delete form. The BDD spec files reference "Owner Account" — that is the name used in automated unit tests with isolated user fixtures and does not apply to browser-based QA testing.

## What To Test

### Scenario 1 — Owner sees the Danger Zone delete section (criterion 4167, 4175)

1. Log in as `qa@example.com`
2. Navigate to `http://localhost:4070/accounts/settings`
3. Screenshot the full page
4. Verify the "Delete Account" section is visible — look for the element with `data-role="delete-account"` and the heading "Delete Account" in red/error color
5. Verify the "Transfer Ownership" section is also visible (confirms owner-only sections render together)
6. Expected: Danger Zone section is present with a delete form containing two inputs ("Type the account name to confirm" and "Your password") and a red "Delete Account" button

### Scenario 2 — Member (non-owner) does NOT see the delete section (criterion 4167, 4175)

1. Invite `qa-member@example.com` to the QA Test Account as an `admin` via `http://localhost:4070/accounts/members`
2. Log out (clear cookies) and log in as `qa-member@example.com`
3. Navigate to `http://localhost:4070/accounts/settings`
4. Screenshot the page
5. Verify the "Delete Account" section with `data-role="delete-account"` is NOT visible
6. Verify the "Transfer Ownership" section is also NOT visible for the admin
7. Expected: Settings page renders General Settings section (read-only for the shared account, or editable depending on role), but Danger Zone is absent

### Scenario 3 — Warning text is present before any interaction (criterion 4171)

1. Log in as `qa@example.com`
2. Navigate to `http://localhost:4070/accounts/settings`
3. Scroll to the Danger Zone section
4. Screenshot the delete section
5. Verify the warning paragraph contains both the word "permanent" and "irreversible"
6. Expected: Warning reads approximately: "This action is permanent and cannot be undone. This deletion is irreversible — all account data, members, and integrations will be deleted."

### Scenario 4 — Delete rejected when account name does not match (criterion 4169)

1. Log in as `qa@example.com`
2. Navigate to `http://localhost:4070/accounts/settings`
3. Scroll to the delete form (`[data-role="delete-account"]`)
4. Fill the account name input (`input[name="account_name_confirmation"]`) with a wrong name, e.g. "Wrong Name"
5. Fill the password input (`input[name="password"]`) with `hello world!`
6. Click the "Delete Account" button
7. Screenshot the resulting flash message
8. Expected: Flash error message "Account name does not match" is shown; user remains on the settings page

### Scenario 5 — Delete rejected when password is incorrect (criterion 4170)

1. Log in as `qa@example.com`
2. Navigate to `http://localhost:4070/accounts/settings`
3. Scroll to the delete form
4. Fill account name input with the exact team account name: `QA Test Account`
5. Fill password input with a wrong password, e.g. `WrongPassword123!`
6. Click the "Delete Account" button
7. Screenshot the resulting flash message
8. Expected: Flash error message "Incorrect password" is shown; user remains on the settings page

### Scenario 6 — Delete rejected when password is empty (criterion 4170)

1. Log in as `qa@example.com`
2. Navigate to `http://localhost:4070/accounts/settings`
3. Fill account name input with `QA Test Account`
4. Leave password empty
5. Click "Delete Account"
6. Screenshot the result
7. Expected: Error flash containing "password" or "Password" is displayed; deletion does not proceed

### Scenario 7 — Successful account deletion redirects to accounts list with confirmation message (criterion 4169, 4170, 4172, 4174)

Note: This is the destructive test — run it last. After this, the "QA Test Account" will be gone. Re-run seeds if you need to repeat other scenarios.

1. Log in as `qa@example.com`
2. Navigate to `http://localhost:4070/accounts/settings`
3. Screenshot the page before deletion
4. Scroll to the delete form
5. Fill account name input with `QA Test Account` (exact match, case-sensitive)
6. Fill password input with `hello world!`
7. Click the "Delete Account" button
8. Screenshot the result
9. Expected: Page redirects to `/accounts` with an info flash message containing "email" or "confirmation" (e.g., "Account deleted. A confirmation email has been sent.")
10. On the accounts list page, verify "QA Test Account" does NOT appear
11. Navigate to `http://localhost:4070/dev/mailbox` and screenshot — verify a deletion confirmation email was sent to `qa@example.com`

### Scenario 8 — Member cannot access deleted account (criterion 4172, 4173)

After scenario 7 (account deleted):

1. Clear cookies and log in as `qa-member@example.com` (must have been added as a member in scenario 2)
2. Navigate to `http://localhost:4070/accounts`
3. Screenshot the accounts list
4. Expected: "QA Test Account" does NOT appear in the list for the member user — all access grants revoked

### Scenario 9 — Owner cannot access settings of deleted account (criterion 4172)

After scenario 7 (account deleted):

1. Still logged in as `qa@example.com` (or log back in if session expired)
2. Navigate to `http://localhost:4070/accounts/settings`
3. Screenshot the result
4. Expected: The deleted account is no longer the active account; user is redirected to `/accounts` or the settings page shows no account (not "QA Test Account")

## Setup Notes

The Settings page (`/accounts/settings`) loads the first account in the user's account list. Since `qa@example.com` also has a personal account created at registration, the settings page may show the personal account rather than "QA Test Account" if the personal account sorts first.

Before testing deletion scenarios, navigate to `/accounts` first and verify that "QA Test Account" is the active account. If needed, click into "QA Test Account" to make it the active account before navigating to settings. The personal account cannot be deleted (the app returns an error for that), so you must ensure the team account is the active one.

The delete form uses two sets of inputs: flat-named inputs (`account_name_confirmation`, `password`) which are the visible inputs, and `sr-only` nested inputs (`delete_confirmation[account_name]`, `delete_confirmation[password]`). Fill the visible inputs by selector `input[name="account_name_confirmation"]` and `input[name="password"]` within the `#delete-account-form`.

Run scenario 7 (destructive deletion) last. After deletion, re-run `mix run priv/repo/qa_seeds.exs` to restore the seed data for future QA sessions.

## Result Path

`.code_my_spec/qa/455/result.md`
