# MetricFlowWeb.UserLive.Settings

User account settings page. Allows authenticated users to change their email address and update their password. Requires sudo mode (recent re-authentication) before any changes can be applied.

## Type

liveview

## Route

`/users/settings`

Also handles `/users/settings/confirm-email/:token` for completing an email change.

## Params

- `token` (optional): When present in mount params, attempts to finalize an email change via `Users.update_user_email/2`. On success flashes "Email changed successfully."; on failure flashes "Email change link is invalid or it has expired." Then redirects to `/users/settings`.

## Dependencies

- MetricFlow.Users

## Components

None

## User Interactions

- **phx-change="validate_email"**: Validates the email changeset on each keystroke using `Users.change_user_email/3` with `validate_unique: false`, sets `:action` to `:validate`, and reassigns the `email_form`.
- **phx-submit="update_email"**: Asserts `Users.sudo_mode?/1` is true. Validates the email changeset via `Users.change_user_email/2`. If valid, calls `Users.deliver_user_update_email_instructions/3` with the confirmation URL builder and shows an info flash ("A link to confirm your email change has been sent to the new address."). If invalid, reassigns the form with action `:insert` to display errors.
- **phx-change="validate_password"**: Validates the password changeset on each keystroke using `Users.change_user_password/3` with `hash_password: false`, sets `:action` to `:validate`, and reassigns the `password_form`.
- **phx-submit="update_password"**: Asserts `Users.sudo_mode?/1` is true. Validates the password changeset via `Users.change_user_password/2`. If valid, sets `trigger_submit: true` which causes the form to POST to `/users/update-password` via `phx-trigger-action`. If invalid, reassigns the form with action `:insert`.

## Design

Layout: Centered single-column with text-center header.

Mount behavior:
- When a `token` param is present, processes the email confirmation immediately and redirects back to `/users/settings`.
- Otherwise, initializes `email_form` from `Users.change_user_email/3` and `password_form` from `Users.change_user_password/3`, both with validation disabled. Assigns `current_email` and `trigger_submit: false`.

Main content (top to bottom):
- Header: "Account Settings" title with subtitle "Manage your account email address and password settings".
- Email change form (`#email_form`): email input with `autocomplete="username"`, primary submit button "Change Email" with `phx-disable-with="Changing..."`.
- Divider: `.divider` separating the two forms.
- Password change form (`#password_form`): hidden email input for autocomplete, new password input (`autocomplete="new-password"`), confirm new password input, primary submit button "Save Password" with `phx-disable-with="Saving..."`. The form POSTs to `/users/update-password` via `phx-trigger-action` when `@trigger_submit` is true.

Components: `.header`, `.form`, `.input`, `.button`, `.divider`

Responsive: Single-column layout works on all screen sizes.

## Test Assertions

- renders settings page with email and password change forms
- validates email on change and shows inline errors for invalid email
- sends email change confirmation link on valid email submit
- shows error when submitting email change outside sudo mode
- validates password on change and shows inline errors
- triggers password form submission on valid password submit
- processes email confirmation token and shows success flash
- shows error flash for invalid or expired email confirmation token

