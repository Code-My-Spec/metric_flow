# MetricFlowWeb.UserLive.Registration

User registration and account creation.

## Type

liveview

## Route

`/users/register`

## Params

None

## User Interactions

- **phx-change="validate"**: Live-validate the email field on each keystroke. Calls `Users.change_user_email/3` with `validate_unique: false` and sets `:validate` action on the changeset so inline errors render without a full submission attempt.
- **phx-submit="save"**: Submit the registration form. Calls `Users.register_user/1` with the form params. On success, delivers login instructions via `Users.deliver_login_instructions/2`, sets an info flash message, and navigates to `/users/log-in`. On failure, re-renders the form with changeset errors.
- **navigate="/users/log-in"**: Navigating to the Log in link redirects the browser to `/users/log-in` without a round-trip event.

## Dependencies

- MetricFlow.Users

## Components

None

## Design

Layout: Centered single-column page with a narrow content column (`max-w-sm`, horizontally centered).

Header section:
  - `.header` component with title "Register for an account"
  - Subtitle with a `Log in` link (`.link`, brand color) navigating to `/users/log-in`
  - Header block is center-aligned

Form section:
  - Form ID: `registration_form`
  - Single `.input` field for email (type="email", autofocused on mount via `phx-mounted` JS hook)
  - Submit button: `.btn.btn-primary` full-width, label "Create an account", shows "Creating account..." while disabled during submission
  - Form uses `phx-submit="save"` and `phx-change="validate"`
  - Inline validation errors appear beneath the email field on change events

Flash messages:
  - On successful registration: info alert rendered by `Layouts.app` — "An email was sent to {email}, please access it to confirm your account."
  - On validation failure: inline field errors from changeset, no flash

Theme tokens: `.btn-primary` (indigo), `.input` (default dark theme input). Wrapping layout provided by `Layouts.app` with aurora background and top navigation.

Responsive: Single-column layout, stacks naturally on all screen sizes. `max-w-sm` caps width on larger screens and centers the form.
