# QA Story Brief

Story 427 — Agency Team Auto-Enrollment

## Tool

web (Vibium MCP browser automation — all routes are LiveView behind session auth)

## Auth

Log in as the agency owner using the password form:

```
mcp__vibium__browser_launch(headless: true)
mcp__vibium__browser_navigate(url: "http://localhost:4070/users/log-in")
mcp__vibium__browser_scroll(selector: "#login_form_password")
mcp__vibium__browser_fill(selector: "#login_form_password_email", text: "qa@example.com")
mcp__vibium__browser_fill(selector: "#user_password", text: "hello world!")
mcp__vibium__browser_click(selector: "#login_form_password button[name='user[remember_me]']")
mcp__vibium__browser_wait(selector: "body", timeout: 5000)
```

To switch to the auto-enrolled member during testing (scenario 3964/3968), clear cookies and log in with the new user's credentials before attempting the member-perspective checks.

## Seeds

Run the base QA seeds before testing — they create the owner user and the "QA Test Account" team account:

```bash
cd /Users/johndavenport/Documents/github/metric_flow
mix run priv/repo/qa_seeds.exs
```

The seeds produce:
- Owner: `qa@example.com` / `hello world!`
- Member: `qa-member@example.com` / `hello world!`
- Team account: "QA Test Account" (qa@example.com is owner)

No additional seed scripts are needed. Test-specific data (unique email domains, new registrations) is created through the UI during testing.

## What To Test

### Scenario 1 — Agency owner sees Auto-Enrollment section (criterion 3963)

- Log in as `qa@example.com`
- Navigate to `http://localhost:4070/accounts/settings`
- Take a screenshot
- Verify the page contains the text "Auto-Enrollment"
- Verify the element `[data-role='auto-enrollment-domain-input']` is present on the page
- Verify the element `[data-role='auto-enrollment-default-role']` (access level select) is present
- Expected: both elements visible in an "Auto-Enrollment" card section below the general settings

### Scenario 2 — Owner configures domain-based auto-enrollment (criterion 3963)

- Navigate to `http://localhost:4070/accounts/settings`
- Fill `[data-role='auto-enrollment-domain-input']` with `myagency.com`
- Leave the Default Access Level at its default (Read Only)
- Click the "Enable Auto-Enrollment" submit button (`button[type='submit']` inside `#auto-enrollment-form`)
- Take a screenshot
- Verify the flash message "Auto-enrollment enabled" appears
- Verify `myagency.com` is displayed on the page after saving

### Scenario 3 — New user with matching domain is auto-enrolled (criterion 3964)

- While still on the settings page, configure auto-enrollment for domain `testco-qa.com` (use this to avoid collision with scenario 2)
- Open a new incognito-style context: clear cookies with `mcp__vibium__browser_delete_cookies()`
- Navigate to `http://localhost:4070/users/register`
- Register a new user with email `newuser@testco-qa.com`, password `SecurePassword123!`, account name `Test Employee`
- Take a screenshot of the post-registration confirmation page
- Clear cookies again and log back in as `qa@example.com`
- Navigate to `http://localhost:4070/accounts/members`
- Take a screenshot
- Verify `newuser@testco-qa.com` appears in the members list
- Also verify that registering with a non-matching domain (e.g., `outsider@otherdomain.com`) does NOT result in that user appearing in the members list

### Scenario 4 — Auto-enrolled user gets the configured default access level (criterion 3965)

- Navigate to `http://localhost:4070/accounts/settings`
- Configure auto-enrollment for a unique domain (e.g., `readonlydomain.com`) with Default Access Level set to "Read Only"
- Submit and verify "Auto-enrollment enabled" flash
- Clear cookies and register a new user with email `employee@readonlydomain.com`, password `SecurePassword123!`, account name `Employee Account`
- Clear cookies and log back in as `qa@example.com`
- Navigate to `http://localhost:4070/accounts/members`
- Take a screenshot
- Verify `employee@readonlydomain.com` appears in the members list
- Verify the role displayed for that user is `read_only` (or "Read Only")

### Scenario 5 — Admin can view and manage auto-enrolled members (criterion 3966)

- Navigate to `http://localhost:4070/accounts/members`
- Verify column headers: "Member", "Role", "Actions" are visible on the page
- Verify the auto-enrolled user from scenario 4 appears in the list
- Attempt to change the role: look for a `[data-role='change-role']` element or a role-change select/button next to the enrolled user
- If available, change the role to "Account Manager" and verify "Role updated" flash appears
- Take a screenshot

### Scenario 6 — Admin can disable auto-enrollment (criterion 3967)

- Navigate to `http://localhost:4070/accounts/settings`
- If no active rule exists, enable one for a new unique domain first (e.g., `todisable.com`)
- Verify the "Disable" button (`[data-role='disable-auto-enrollment']`) is visible when enrollment is active
- Click the Disable button
- Take a screenshot
- Verify the flash message "Auto-enrollment disabled" appears
- Verify the "Active" badge is no longer shown (a "Disabled" badge should appear instead)
- Register a new user with an email from the previously-active domain
- Log back in as `qa@example.com` and navigate to `/accounts/members`
- Verify the newly registered user does NOT appear in the members list

### Scenario 7 — Auto-enrolled members inherit access to client accounts (criterion 3968)

- This scenario requires client accounts to be granted to the agency. The BDD spec uses `Agencies.grant_client_account_access/5` directly from Elixir, which cannot be driven entirely through the current UI (client account management is a separate story).
- Navigate to `http://localhost:4070/accounts/settings` and verify the agency settings sections render without error
- Take a screenshot showing the auto-enrollment and white-label sections
- Note in the result that the full client-account inheritance scenario requires either a separate seed script or a future client-account-management UI; test what can be verified through the UI (auto-enrollment configuration and member visibility)

### Additional — Non-admin/personal account does not see agency sections

- Log out and log in as `qa-member@example.com` (who has no team account by default)
- Navigate to `http://localhost:4070/accounts/settings`
- Verify the "Auto-Enrollment" section is NOT present on the page
- Take a screenshot

## Setup Notes

The agency sections (Auto-Enrollment, White-Label Branding) are conditionally rendered only when:
1. The active account type is `"team"`, AND
2. The current user holds the `owner` or `admin` role

The seeded "QA Test Account" is a team account and `qa@example.com` is its owner, so the full agency settings UI should be visible when logged in as that user.

The auto-enrollment domain input uses `name="auto_enrollment[domain]"` — note this maps to `email_domain` in the schema, but the form param key is `domain`. The access level select uses `name="auto_enrollment[default_access_level]"` with values `read_only`, `account_manager`, `admin`.

When verifying member roles, the BDD specs assert `html =~ "read_only"` (atom string form), so look for the raw string `read_only` in the rendered page rather than a human-readable label.

The disable button (`[data-role='disable-auto-enrollment']`) only appears when a rule exists AND `enabled == true`. After saving a new rule, the button should be immediately visible without a page reload.

Registration in MetricFlow shows a confirmation screen after submit (not an immediate redirect). The auto-enrollment hook fires on registration — the user will appear in the members list when the owner checks `/accounts/members` even before the new user confirms their email.

## Result Path

`.code_my_spec/qa/427/result.md`
