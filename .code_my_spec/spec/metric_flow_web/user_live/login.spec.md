# MetricFlowWeb.UserLive.Login

User login and session management. Provides two authentication paths: a magic link sent to the user's email address, and direct password-based login. Also handles re-authentication (sudo mode) when a user who is already signed in needs to confirm their identity before performing a sensitive action.

## Type

liveview

## Route

`/users/log-in`

## Params

None

## Dependencies

- MetricFlow.Users

## Components

None

## User Interactions

- **phx-submit="submit_magic"**: Extract email from params. Call `Users.get_user_by_email/1`; if the user exists, call `Users.deliver_login_instructions/2` with the magic link URL builder `&url(~p"/users/log-in/#{&1}")`. Always put an ambiguous info flash ("If your email is in our system, you will receive instructions for logging in shortly.") and `push_navigate` back to `/users/log-in`. Never reveals whether an address is registered.
- **phx-submit="submit_password"**: Assign `trigger_submit: true` to the socket. The `phx-trigger-action` binding on `#login_form_password` detects the truthy value and POSTs the form to `UserSessionController`, which verifies credentials and creates the session. On success the controller redirects to `/`; on failure it redirects back to `/users/log-in` with an "Invalid email or password" error flash.
- **navigate to /users/register**: Clicking "Sign up" navigates the unauthenticated user to the registration page. This link is hidden when `current_scope` is present (sudo mode).
- **navigate to /dev/mailbox**: Clicking the mailbox link in the dev info banner opens the Swoosh local mailbox. Only shown when running the local mail adapter.

## Design

Layout: Centered single-column, max width `sm`, with vertical spacing between sections.

Mount behavior:
- Reads `:email` from flash first (present after a failed password login redirects back), then falls back to `current_scope.user.email` (sudo re-auth mode). Builds a `form` assign from that value and sets `trigger_submit: false`.

Main content (top to bottom):
- Header: "Log in" title. Subtitle slot shows "Sign up" link for unauthenticated visitors, or "You need to reauthenticate" notice when `current_scope` is present.
- Alert banner (conditional, dev only): `alert alert-info` with icon, explanation of local mail adapter, and link to `/dev/mailbox`.
- Magic link form (`#login_form_magic`): email input (readonly in sudo mode, auto-focused on mount), `btn-primary w-full` submit button labeled "Log in with email →".
- Divider: `.divider` with text "or".
- Password form (`#login_form_password`): email input (readonly in sudo mode), password input, two submit buttons — "Log in and stay logged in →" (`btn-primary w-full`, carries `remember_me=true`) and "Log in only this time" (`btn-primary btn-soft w-full`). `phx-trigger-action` bound to `@trigger_submit`.

Components: `.alert`, `.alert-info`, `.form-control`, `.input`, `.btn`, `.btn-primary`, `.btn-soft`, `.divider`, `.header`

Responsive: Single-column layout works on all screen sizes; max-width constrains wide-screen display.
