# QA Result

Story 425: User Login and Session Management

## Status

partial

## Scenarios

### Scenario 1: Password login with valid credentials

**Result: pass**

Navigated to `http://localhost:4070/users/log-in`. Page rendered correctly with the heading
"Log in", both forms present (`#login_form_magic` and `#login_form_password`), and both
session-length buttons visible.

POSTed to `POST /users/log-in` with `qa@example.com` / `hello world!` and `remember_me=true`.
Server responded HTTP 302 to `/`. Session cookie decoded to confirm `phoenix_flash.info =
"Welcome back!"`. The `_metric_flow_web_user_remember_me` cookie was set with a 14-day
expiry (`max-age=1209600`).

Evidence: `screenshots/01_login_page.html`, `screenshots/02_login_success_home.html`

### Scenario 2: Magic link login

**Result: partial (not fully testable via curl)**

The magic link form (`#login_form_magic`) is present in the HTML with the correct attributes:
`id="login_form_magic"`, `phx-submit="submit_magic"`, and the "Log in with email" button.

The `phx-submit="submit_magic"` event is handled entirely within the LiveView process over
WebSocket. A curl POST to `/users/log-in` with only an email field (no password key)
triggers a `MatchError` in the controller at line 34 of `user_session_controller.ex`,
returning HTTP 500. This is because curl bypasses the LiveView and posts directly to the
controller which pattern-matches on `%{"email" => email, "password" => password}`.

In normal browser usage, submitting the magic link form never reaches the controller —
the LiveView `handle_event("submit_magic")` function handles it entirely and pushes a
`navigate` redirect. This scenario was not testable with curl. Browser automation (vibium)
was required but unavailable due to a stale socket file blocking daemon startup.

### Scenario 3: Failed login — wrong password

**Result: pass**

POSTed to `POST /users/log-in` with `qa@example.com` and password `WrongPassword999!`.
Server responded HTTP 302 back to `/users/log-in`. Session cookie decoded to confirm
`phoenix_flash.error = "Invalid email or password"`. The error flash was rendered on
the resulting login page.

Evidence: `screenshots/04_login_error_wrong_password.html`

### Scenario 4: Failed login — unregistered email

**Result: pass**

POSTed with `nonexistent@example.com` and `SomePassword123!`. Server responded HTTP 302
back to `/users/log-in`. Flash decoded as `error = "Invalid email or password"` — identical
to the wrong-password message, confirming no email enumeration. The error was rendered on
the resulting login page.

Evidence: `screenshots/05_login_error_unregistered.html`

### Scenario 5: Failed login — empty credentials

**Result: pass**

POSTed with empty email and empty password. Server responded HTTP 302 back to
`/users/log-in`. Flash decoded as `error = "Invalid email or password"`. No crash or
different error code was returned. Error rendered on the login page.

Evidence: `screenshots/06_login_error_empty.html`

### Scenario 6: Session persists across tabs

**Result: pass**

Using the auth cookies from Scenario 1, navigated to `/users/settings`. Page loaded with
"Account Settings" heading and the user's email `qa@example.com` displayed. A "Log out"
link was present. Then navigated to `/accounts`. Page loaded showing "Accounts" content
with LiveView session data — no redirect to login.

Evidence: `screenshots/07_settings_authenticated.html`, `screenshots/08_accounts_authenticated.html`

### Scenario 7: Log out from settings page

**Result: pass**

Logged in fresh, then fetched `/users/settings`. Confirmed "Log out" link present in the
nav (`<a href="/users/log-out" data-method="delete">`). Performed `DELETE /users/log-out`
with the correct CSRF token in the `x-csrf-token` header.

Server responded HTTP 302 to `/`. Two cookies were set in the response:
1. `_metric_flow_web_user_remember_me` was cleared (`max-age=0`, `expires=Thu, 01 Jan 1970`)
2. Session cookie decoded to confirm `phoenix_flash.info = "Logged out successfully."`

The "Logged out successfully." flash message was rendered on the resulting home page.

Evidence: `screenshots/09_settings_with_logout_link.html`, `screenshots/10_logged_out.html`

### Scenario 8: Access protected page after logout

**Result: pass**

After logout, attempted `GET /users/settings` using the post-logout cookie jar. Server
responded HTTP 302 to `/users/log-in`. The redirect cookie contained
`phoenix_flash.error = "You must log in to access this page."`. The flash message was
rendered on the login page after following the redirect.

Evidence: `screenshots/11_post_logout_redirect.html`

### Scenario 9: Unauthenticated access redirects to login

**Result: pass**

Issued `GET /users/settings` with no cookies. Server responded HTTP 302 to `/users/log-in`.
The redirect cookie decoded to `phoenix_flash.error = "You must log in to access this page."`.
Following the redirect to `/users/log-in` rendered the error message on the login page.
`user_return_to` was also set to `/users/settings` in the session.

Evidence: `screenshots/12_unauthenticated_redirect.html`

### Scenario 10: Remember Me buttons visible on login page

**Result: pass**

Both session-length buttons are present in `#login_form_password`:
- `<button name="user[remember_me]" value="true">Log in and stay logged in →</button>`
- `<button class="btn btn-primary btn-soft w-full mt-2">Log in only this time</button>`

The "Log in and stay logged in" button has `name="user[remember_me]"` and `value="true"`.
The "Log in only this time" button has no name attribute, so clicking it omits `remember_me`
from the form submission.

Evidence: `screenshots/13_remember_me_buttons.html`

### Scenario 11: Login with Remember Me sets cookie

**Result: pass**

POSTed with `remember_me=true`. Response included
`set-cookie: _metric_flow_web_user_remember_me=...; max-age=1209600; HttpOnly; SameSite=Lax`
(14-day expiry). Redirect was HTTP 302 to `/`. Session cookie flash confirmed "Welcome back!".

### Scenario 12: Login without Remember Me does not set cookie

**Result: pass**

POSTed without the `remember_me` field. Response contained only the session cookie
`_metric_flow_key`. The `_metric_flow_web_user_remember_me` cookie was NOT set.
Redirect was HTTP 302 to `/`. Session cookie flash confirmed "Welcome back!".

## Evidence

- `.code_my_spec/qa/425/screenshots/01_login_page.html` — login page with both forms and both session buttons
- `.code_my_spec/qa/425/screenshots/02_login_success_home.html` — home page after successful login (flash: "Welcome back!")
- `.code_my_spec/qa/425/screenshots/04_login_error_wrong_password.html` — login page with "Invalid email or password" flash (wrong password)
- `.code_my_spec/qa/425/screenshots/05_login_error_unregistered.html` — login page with "Invalid email or password" flash (unregistered email)
- `.code_my_spec/qa/425/screenshots/06_login_error_empty.html` — login page with "Invalid email or password" flash (empty credentials)
- `.code_my_spec/qa/425/screenshots/07_settings_authenticated.html` — account settings page showing authenticated user email
- `.code_my_spec/qa/425/screenshots/08_accounts_authenticated.html` — accounts page loaded without redirect (session persists)
- `.code_my_spec/qa/425/screenshots/09_settings_with_logout_link.html` — settings page showing "Log out" link in nav
- `.code_my_spec/qa/425/screenshots/10_logged_out.html` — home page after logout (flash: "Logged out successfully.")
- `.code_my_spec/qa/425/screenshots/11_post_logout_redirect.html` — login page after accessing settings post-logout (flash: "You must log in")
- `.code_my_spec/qa/425/screenshots/12_unauthenticated_redirect.html` — login page after unauthenticated access attempt (flash: "You must log in")
- `.code_my_spec/qa/425/screenshots/13_remember_me_buttons.html` — login page showing both remember me buttons

## Issues

### Vibium daemon stale socket blocks browser-based testing

#### Severity
MEDIUM

#### Scope
QA

#### Description
The vibium daemon socket file at `~/Library/Caches/vibium/vibium.sock` was stale (left
from a previous session). The daemon reported "not running" via `vibium daemon status` but
the socket file existed, causing `vibium daemon start --headless` to fail with "address
already in use". Clearing the stale file requires writing to `~/Library/Caches/vibium/`
which is outside the sandbox's allowed write paths.

This blocked execution of Scenario 2 (magic link flow via LiveView) which requires browser
automation. All other scenarios were completed via curl.

To fix: run `rm -f ~/Library/Caches/vibium/vibium.sock` before starting the daemon, or
update `vibium daemon start` to handle stale socket cleanup automatically.

### POST /users/log-in with email-only body returns HTTP 500

#### Severity
LOW

#### Scope
APP

#### Description
Sending `POST /users/log-in` with `user[email]` but no `user[password]` field returns
HTTP 500. The controller's `create/3` clause at line 34 of `user_session_controller.ex`
pattern-matches with `%{"email" => email, "password" => password} = user_params`, which
raises a `MatchError` when `"password"` is absent from the map.

In normal browser usage this path is never reached: the magic link form uses
`phx-submit="submit_magic"` which is handled by the LiveView process and never POSTs to
the controller. However a direct HTTP POST to the endpoint (e.g. from a script or
malformed request) crashes rather than returning a graceful 400 or redirecting with an
error flash.

To reproduce:
```bash
curl -s -o /dev/null -w "%{http_code}" \
  -X POST http://localhost:4070/users/log-in \
  -b <session-cookies> \
  -d "_csrf_token=<valid-token>&user[email]=qa@example.com"
# Returns: 500
```

Fix: add a catch-all `create/3` clause or guard that handles the email-only case gracefully.
