# MetricFlowWeb.UserLive

User authentication and settings UI views.

## Type

live_context

## LiveViews

### UserLive.Registration

- **Route:** `/users/register`
- **Description:** New user registration form. Creates a user account and sends confirmation instructions.

### UserLive.Login

- **Route:** `/users/log-in`
- **Description:** User login form with email and password authentication.

### UserLive.Confirmation

- **Route:** `/users/log-in/:token`
- **Description:** Email confirmation via magic link token. Validates the token and confirms the user's email.

### UserLive.Settings

- **Route:** `/users/settings` and `/users/settings/confirm-email/:token`
- **Description:** User profile settings. Allows changing email and password. Handles email change confirmation via token.

## Components

None — each LiveView is self-contained.

## Dependencies

- MetricFlow.Users
- MetricFlow.Accounts
- MetricFlow.Agencies
