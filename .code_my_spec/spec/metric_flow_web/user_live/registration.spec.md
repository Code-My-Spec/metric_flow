# MetricFlowWeb.UserLive.Registration

User registration and account creation. Collects email, password, account name, and account type (client or agency). On success, creates the user and account, delivers confirmation email, and shows a success screen.

## Type

liveview

## Route

`/users/register`

## Params

None

## User Interactions

- **phx-change=validate**: Live-validate form fields on each keystroke. Calls `Users.change_user_registration/3` with `validate_unique: false` and sets `:validate` action on the changeset so inline errors render without a full submission attempt.
- **phx-submit=save**: Submit the registration form. Calls `Users.register_user/1` with email, password, account_name, and account_type. On success, creates user and account, delivers login instructions via `Users.deliver_login_instructions/2`, and shows the registration success screen with account name and email confirmation prompt. On failure, re-renders the form with changeset errors.

## Dependencies

- MetricFlow.Users
- MetricFlow.Accounts
- MetricFlow.Agencies

## Components

None

## Design

Layout: Centered single-column page with narrow content column (`max-w-sm`, horizontally centered), wrapped in `Layouts.app`.

**Registration form (shown when not yet registered):**

Header section:
- `.header` component with title "Register for an account"
- Subtitle with "Already registered?" and a `Log in` link navigating to `/users/log-in`
- Center-aligned

Form section (id: `registration_form`):
- Email input: type="email", autofocused on mount via `phx-mounted` JS hook
- Password input: type="password"
- Account name input: type="text", placeholder "Enter your account name"
- Account type select: options "Client" and "Agency" with "Select account type" prompt
- Submit button: `.btn .btn-primary` full-width, label "Create an account", shows "Creating account..." while disabled
- Form uses `phx-submit="save"` and `phx-change="validate"`
- Inline validation errors appear beneath fields on change events

**Success screen (shown after registration):**

- Header: Registration successful
- Account name confirmation: Account {name} has been created.
- Email confirmation prompt: An email was sent to {email}. Please confirm your account to get started.

Responsive: Single-column layout stacks naturally. `max-w-sm` caps width on larger screens.

## Test Assertions

- renders registration form with email, password, account name, and account type fields
- autofocuses email input on mount
- shows Already registered? subtitle with link to log in page
- redirects to signed-in path if user is already logged in
- live-validates email format on change and shows inline error for invalid email
- shows has already been taken error when submitting a duplicate email
- creates user and shows success screen with confirmation email message on valid submit
- displays account name confirmation on success screen when account name was provided
- shows Creating account... on submit button while form is processing
- navigates to login page when Log in link is clicked
