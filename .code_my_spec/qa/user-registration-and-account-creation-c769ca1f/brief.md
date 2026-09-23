# QA Brief — Story 424: User Registration and Account Creation

## Tool

vibium MCP server for all form interaction, LiveView validation, and screenshot evidence.
`curl` for verifying unauthenticated redirect behavior on protected routes.

## Auth

Registration tests use fresh unique emails — do not use the seeded `qa@example.com` user, as that email is already taken and would trigger a duplicate-email error.

For any scenario that requires an already-authenticated user (e.g., verifying redirect away from register page), launch the browser and log in via MCP tools:

```
mcp__vibium__browser_launch(headless: true)
mcp__vibium__browser_navigate(url: "http://localhost:4070/users/log-in")
mcp__vibium__browser_scroll_into_view(selector: "#login_form_password")
mcp__vibium__browser_fill(selector: "#login_form_password_email", text: "qa@example.com")
mcp__vibium__browser_fill(selector: "#user_password", text: "hello world!")
mcp__vibium__browser_click(selector: "#login_form_password button[name='user[remember_me]']")
mcp__vibium__browser_wait(selector: "body", timeout: 5000)
```

## Seeds

Run before testing:

```bash
mix run priv/repo/qa_seeds.exs
```

This ensures the `qa@example.com` user exists in the database, which is needed for the duplicate-email rejection scenario.

## What To Test

### Scenario 1: Registration form renders correctly

Navigate to `/users/register` and verify the form is present with all required fields.

Steps:
1. Navigate to `http://localhost:4070/users/register` via `mcp__vibium__browser_navigate`
2. Capture screenshot: `01_registration_form.png`
3. Verify heading reads "Register for an account" via `mcp__vibium__browser_get_text(selector: "h1")`
4. Verify form elements via `mcp__vibium__browser_find(selector: "#registration_form")`
5. Confirm the following fields exist: Email, Password, Account name, Account type (select)
6. Confirm the submit button reads "Create an account"

Expected: Form renders with all four fields and a submit button. Account type select shows "Client" and "Agency" as options with a "Select account type" prompt.

### Scenario 2: Successful registration with account name and type

Submit the registration form with valid data including account name and account type.

Steps:
1. Navigate to `http://localhost:4070/users/register`
2. Fill Email with a unique address (e.g., `qa-new-424@example.com`)
3. Fill Password with `hello world!` (12 characters, meets minimum)
4. Fill Account name with `My Test Agency`
5. Select Account type `Agency`
6. Click the "Create an account" button
7. Wait for text "Registration successful" via `mcp__vibium__browser_wait_for_text`
8. Capture screenshot: `02_registration_success.png`
9. Verify confirmation message mentions the account name and email

Expected: Page shows "Registration successful" heading, states `Account "My Test Agency" has been created`, and instructs the user to check email to confirm their account. No redirect to dashboard — user stays on confirmation screen.

### Scenario 3: Email verification is required (magic link sent)

After registration, verify that a confirmation email is sent and login requires confirmation.

Steps:
1. Complete registration as in Scenario 2 (or use a second unique email)
2. Navigate to `http://localhost:4070/dev/mailbox`
3. Capture screenshot: `03_dev_mailbox.png`
4. Verify a login/confirmation email appears addressed to the registered email

Expected: Dev mailbox shows one email sent to the registered address containing a magic link login URL.

### Scenario 4: Password too short is rejected

Submit registration with a password shorter than 12 characters and verify inline validation error.

Steps:
1. Navigate to `http://localhost:4070/users/register`
2. Fill Email with a unique address
3. Fill Password with `short` (5 characters)
4. Fill Account name with `Test`
5. Click the "Create an account" button
6. Capture screenshot: `04_password_too_short.png`
7. Verify password error message via `mcp__vibium__browser_get_text`

Expected: Form stays on the registration page and shows an error on the password field indicating it is too short (minimum 12 characters). No registration occurs.

### Scenario 5: Invalid email format is rejected

Submit registration with a malformed email address.

Steps:
1. Navigate to `http://localhost:4070/users/register`
2. Fill Email with `notanemail` (no @ sign)
3. Fill Password with `hello world!`
4. Fill Account name with `Test`
5. Click the "Create an account" button
6. Capture screenshot: `05_invalid_email.png`
7. Verify email error message

Expected: Form shows an error on the email field indicating it must have the @ sign and no spaces.

### Scenario 6: Duplicate email is rejected with clear error

Attempt to register with an email that already exists in the database.

Steps:
1. Navigate to `http://localhost:4070/users/register`
2. Fill Email with `qa@example.com` (the seeded user — already exists)
3. Fill Password with `hello world!`
4. Fill Account name with `Duplicate Test`
5. Click the "Create an account" button
6. Capture screenshot: `06_duplicate_email.png`
7. Verify an error message is shown for the email field

Expected: Form stays on the registration page and shows an error on the email field (e.g., "has already been taken"). The duplicate email is clearly rejected.

### Scenario 7: Missing account name is rejected

Submit registration without filling in the account name field.

Steps:
1. Navigate to `http://localhost:4070/users/register`
2. Fill Email with a unique address
3. Fill Password with `hello world!`
4. Leave Account name blank
5. Click the "Create an account" button
6. Capture screenshot: `07_missing_account_name.png`
7. Verify account name error message

Expected: Form shows an error on the account name field indicating it is required.

### Scenario 8: Already-logged-in user is redirected away from register page

A logged-in user visiting `/users/register` should be redirected to the signed-in path.

Steps:
1. Run `mix run priv/repo/qa_seeds.exs` (seeds QA user)
2. Log in via MCP tools (see Auth section above)
3. Navigate to `http://localhost:4070/users/register`
4. Check current URL via `mcp__vibium__browser_get_url`
5. Capture screenshot: `08_logged_in_redirect.png`

Expected: User is redirected away from `/users/register` and lands on the signed-in path (e.g., `/onboarding` or `/accounts`), not the registration form.

## Result Path

`.code_my_spec/qa/424/result.md`

Screenshots: `.code_my_spec/qa/424/screenshots/`
