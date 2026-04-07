# MetricFlowWeb.AccountLive

Account management UI views.

## Type

live_context

## LiveViews

### AccountLive.Index

- **Route:** `/accounts`
- **Description:** Lists all personal and team accounts for the authenticated user with membership roles, agency access levels, and account switching. Includes inline form for creating new team accounts.

### AccountLive.Members

- **Route:** `/accounts/members`
- **Description:** Manages account members and permissions. Displays members with roles and join dates. Owners and admins can change roles, remove members, and invite new users by email.

### AccountLive.Settings

- **Route:** `/accounts/settings`
- **Description:** Account settings, ownership transfer, and deletion. Owners and admins can edit name and slug. Owners can transfer ownership or delete team accounts. Renders agency auto-enrollment and white-label sections for team account owners/admins.

## Components

None — each LiveView is self-contained.

## Dependencies

- MetricFlow.Accounts
- MetricFlow.Agencies
- MetricFlow.Users
