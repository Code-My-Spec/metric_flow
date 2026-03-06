# QA Story Brief

Story 425: User Login and Session Management

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

```bash
cd /Users/johndavenport/Documents/github/metric_flow
mix run priv/repo/qa_seeds.exs
```

Creates (idempotent):
- QA user: `qa@example.com` / `hello world!` (email confirmed, password login enabled)
- Personal account: "QA Personal"
- Team account: "QA Test Account"

No story-specific seeds are needed beyond the base seeds.

## What To Test

### Scenario 1: Password login with valid credentials (AC: User can log in with email and password)

- Navigate to `http://localhost:4070/users/log-in`
- Verify the page heading "Log in" is visible
- Verify both forms are present: `#login_form_magic` and `#login_form_password`
- Take screenshot: `screenshots/01_login_page.png`
- Fill `#login_form_password input[type=email]` with `qa@example.com`
- Fill `#login_form_password input[type=password]` with `hello world!`
- Click `#login_form_password button[name='user[remember_me]']` ("Log in and stay logged in")
- Wait: `mcp__vibium__browser_wait(selector: "body", timeout: 5000)`
- Verify current URL is no longer `/users/log-in` (redirected to `/`)
- Verify "Welcome back!" flash message is shown
- Take screenshot: `screenshots/02_login_success.png`

### Scenario 2: Magic link login (AC: User can log in with email and password)

- Navigate to `http://localhost:4070/users/log-in`
- Fill `#login_form_magic input[type=email]` with `qa@example.com`
- Click `#login_form_magic button` ("Log in with email")
- Wait for redirect back to `/users/log-in`
- Verify page shows "If your email is in our system" info flash
- Take screenshot: `screenshots/03_magic_link_sent.png`

### Scenario 3: Failed login — wrong password (AC: Failed login attempts show clear error messages)

- Navigate to `http://localhost:4070/users/log-in`
- Fill `#login_form_password input[type=email]` with `qa@example.com`
- Fill `#login_form_password input[type=password]` with `WrongPassword999!`
- Click "Log in and stay logged in"
- Wait for redirect back to the login page
- Verify error flash "Invalid email or password" is shown
- Take screenshot: `screenshots/04_login_error_wrong_password.png`

### Scenario 4: Failed login — unregistered email (AC: Failed login attempts show clear error messages)

- Navigate to `http://localhost:4070/users/log-in`
- Fill `#login_form_password input[type=email]` with `nonexistent@example.com`
- Fill `#login_form_password input[type=password]` with `SomePassword123!`
- Click "Log in and stay logged in"
- Wait for redirect back to the login page
- Verify error flash "Invalid email or password" is shown (same message as wrong password — no email enumeration)
- Take screenshot: `screenshots/05_login_error_unregistered.png`

### Scenario 5: Failed login — empty credentials (AC: Failed login attempts show clear error messages)

- Navigate to `http://localhost:4070/users/log-in`
- Leave email and password fields empty in `#login_form_password`
- Click "Log in and stay logged in"
- Wait for response
- Verify an error message is shown (either browser HTML5 validation or "Invalid email or password" flash)
- Take screenshot: `screenshots/06_login_error_empty.png`

### Scenario 6: Session persists across tabs (AC: User session persists across browser tabs)

- Ensure authenticated (log in via MCP tools — see Auth section)
- Navigate to `http://localhost:4070/users/settings`
- Verify the page shows "Account Settings" and the email `qa@example.com`
- Take screenshot: `screenshots/07_settings_authenticated.png`
- Navigate to `http://localhost:4070/accounts`
- Verify the accounts page loads and shows "Accounts" content (not redirected to login)
- Take screenshot: `screenshots/08_accounts_authenticated.png`

### Scenario 7: Log out from settings page (AC: User can log out from any page)

- Ensure authenticated (log in via MCP tools — see Auth section)
- Navigate to `http://localhost:4070/users/settings`
- Verify "Log out" link is visible on the page
- Take screenshot: `screenshots/09_settings_with_logout_link.png`
- Click the "Log out" link (find it via `mcp__vibium__browser_find(role: "link", text: "Log out")` or check the nav)
- Wait for redirect
- Verify current URL is `/`
- Verify "Logged out successfully." flash message is shown
- Take screenshot: `screenshots/10_logged_out.png`

### Scenario 8: Access protected page after logout (AC: User can log out from any page)

- After logging out (continuing from Scenario 7, or log out then proceed)
- Navigate to `http://localhost:4070/users/settings`
- Verify the page redirects to `/users/log-in` (session is invalidated)
- Take screenshot: `screenshots/11_post_logout_redirect.png`

### Scenario 9: Unauthenticated access redirects to login (AC: Inactive sessions expire after a reasonable period)

- Verify unauthenticated redirect with curl (no cookies):
  ```bash
  curl -s -o /dev/null -w "%{http_code}" http://localhost:4070/users/settings
  ```
- Expected: `302`
- Navigate to `http://localhost:4070/users/settings` in the browser without an active session (clear cookies via `mcp__vibium__browser_delete_cookies()` first)
- Verify the app redirects to `/users/log-in`
- Verify the flash message "You must log in to access this page." is shown
- Take screenshot: `screenshots/12_unauthenticated_redirect.png`

### Scenario 10: Remember Me buttons visible on login page (AC: User can use Remember me option for extended sessions)

- Navigate to `http://localhost:4070/users/log-in`
- Verify the page shows both session-length options in `#login_form_password`:
  - "Log in and stay logged in" (button with `name="user[remember_me]"` and `value="true"`)
  - "Log in only this time" (button without `name` or `remember_me` value)
- Take screenshot: `screenshots/13_remember_me_buttons.png`

### Scenario 11: Login with Remember Me sets cookie (AC: User can use Remember me option for extended sessions)

- Use curl to POST the login form and capture cookies:
  ```bash
  curl -v -c /tmp/qa_cookies_rm.txt \
    -d "user[email]=qa@example.com&user[password]=hello+world!&user[remember_me]=true" \
    http://localhost:4070/users/log-in
  grep _metric_flow_web_user_remember_me /tmp/qa_cookies_rm.txt && echo "PASS: remember_me cookie is set" || echo "FAIL: remember_me cookie not found"
  ```
- Verify redirect to `/` (HTTP 302) in the response
- Verify `_metric_flow_web_user_remember_me` cookie is present

### Scenario 12: Login without Remember Me does not set cookie (AC: User can use Remember me option for extended sessions)

- Use curl to POST the login form without remember_me:
  ```bash
  curl -v -c /tmp/qa_cookies_no_rm.txt \
    -d "user[email]=qa@example.com&user[password]=hello+world!" \
    http://localhost:4070/users/log-in
  grep _metric_flow_web_user_remember_me /tmp/qa_cookies_no_rm.txt && echo "FAIL: unexpected cookie" || echo "PASS: remember_me cookie not set"
  ```
- Verify redirect to `/` (HTTP 302) in the response
- Verify `_metric_flow_web_user_remember_me` cookie is NOT present

## Setup Notes

The login page renders two forms side-by-side. Always target `#login_form_password` for
password-based login. The password form uses `phx-trigger-action`: clicking submit fires a
LiveView event that sets `trigger_submit: true`, then the browser performs a native POST to
`/users/log-in` handled by `UserSessionController`. The redirect on success goes to `/`.

The "Log in and stay logged in" button carries `name="user[remember_me]" value="true"`.
The "Log in only this time" button has no name/value — submitting via that button omits
`remember_me` from the form data, resulting in a session-only token.

Dev mailbox for magic link emails: `http://localhost:4070/dev/mailbox`

## Result Path

`.code_my_spec/qa/425/result.md`
