# return_to parameter not honored after password login for invited users

## Severity

medium

## Scope

app

## Description

When an unauthenticated user on  /invitations/:token  clicks "Log In to Accept", they are redirected to  /users/log-in?return_to=/invitations/:token . After successfully submitting the password login form, the app redirected to  /  (home page) instead of the  return_to  URL. Steps to reproduce: Navigate to an invitation URL while not logged in (e.g.,  /invitations/wV8UQ6kL6suzRr97au-enZEjjrJHWdRLZULQjWLQQAY ) Click "Log In to Accept" — redirected to  /users/log-in?return_to=/invitations/... Submit the password login form with valid credentials Expected: redirected back to  /invitations/...  to complete acceptance Actual: redirected to  /  (home page) The user can still manually navigate to the invitation URL after login to accept, but the intended UX flow is broken. This may be a pre-existing issue unrelated to story 432.

## Source

QA Story 432 — `.code_my_spec/qa/432/result.md`

## Resolution

Fixed the login flow to honor the `return_to` query parameter.

**Root cause:** The login LiveView received `return_to` as a URL query parameter but never forwarded it to the session controller. When the password form submitted to `POST /users/log-in`, the controller called `UserAuth.log_in_user/3` which reads `:user_return_to` from the Plug session — but that key was never set, so it fell back to `/`.

**Fix:**
- `login.ex` — `mount/3` now reads `return_to` from params and assigns it to the socket. The password form includes a hidden input `<input type="hidden" name="return_to" value={@return_to} />`.
- `user_session_controller.ex` — The password `create/3` clause now calls `maybe_store_return_to/2` which reads `return_to` from the form params and stores it in the session via `put_session(conn, :user_return_to, return_to)`. `UserAuth.log_in_user/3` already reads this key before renewing the session.

**Files changed:**
- `lib/metric_flow_web/live/user_live/login.ex` — mount assigns + hidden form field
- `lib/metric_flow_web/controllers/user_session_controller.ex` — `maybe_store_return_to/2` helper

**Verification:** All 44 invitation tests pass. Full test suite confirms no regressions.
