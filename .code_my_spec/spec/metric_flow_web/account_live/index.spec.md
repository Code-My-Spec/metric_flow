# MetricFlowWeb.AccountLive.Index

List all accounts the authenticated user belongs to. Displays personal and team accounts with account type, the user's role in each, and any agency access level and origination status for client accounts accessed via an agency grant. Highlights the currently active account and allows switching the active account context. Includes an inline form for creating new team accounts. Requires authentication; unauthenticated requests are redirected to `/users/log-in`. Subscribes to PubSub on mount for real-time account updates.

## Type

liveview

## Route

`/accounts`

## Params

None

## Dependencies

- MetricFlow.Accounts
- MetricFlow.Agencies

## Components

None

## User Interactions

- **phx-click="switch_account" phx-value-account_id**: Calls `Accounts.select_active_account/2` with the given account ID. Updates the active account in scope, re-renders all account cards so the selected account has `data-active="true"` and all others have `data-active="false"`. The switch button for the now-active account becomes disabled with label "Active". Only accepts account IDs the user is already a member of. Shows an info flash "Switched to {account name}".
- **phx-submit="create_team"**: Validates and submits the new team account form with `name` and `slug` fields. Calls `Accounts.create_team_account/2`. On success, clears the form, shows a success flash "Team account created", and appends the new account to the list. On validation error, re-renders the form inline with field-level errors without clearing user input.
- **phx-change="validate_team"**: Live-validates the new team account form as the user types. Calls `Accounts.change_account/3` with the current params and re-renders field errors inline. Does not persist any data.
- **handle_info {:created | :updated | :deleted, account}**: On mount (when socket is connected), subscribes to `Accounts.subscribe_account/1` scoped to the current user. On receiving any of these PubSub messages, calls `Accounts.list_accounts/1` to refresh the full accounts list. The active account highlight is preserved across refreshes — the card matching the current active account retains `data-active="true"`.

## Design

Layout: Centered single-column page, max-width 2xl, with top padding.

Header:
- H1 "Your Accounts"

Account list (renders for each account the user belongs to):
- One `.card.bg-base-200` row per account with `data-role="account-card"`, `data-account-id="{id}"`, and `data-active="true"` or `data-active="false"` depending on whether the account matches the currently active context
- Account name as a bold heading
- `.badge.badge-primary` or `.badge.badge-ghost` indicating account type: "Personal" for personal accounts, "Team" for team accounts
- `.badge` showing the user's membership role in the account (e.g., "owner", "member", "read_only")
- For client accounts accessed via an agency grant: an additional `.badge` showing the access level (e.g., "Account Manager", "Admin", "Read Only") and a separate `.badge` showing origination status ("Originator" or "Invited")
- Right side: a `[data-role="switch-account"]` button with `phx-value-account_id`. Disabled and labeled "Active" when the account is the current active context; labeled "Switch" when inactive

Empty state (shown when the user belongs to no accounts):
- Muted text "No accounts found."

Create Team Account form (`form[phx-submit="create_team"]`, `phx-change="validate_team"`):
- Name input (`name="team[name]"`), with inline `.label-text-alt` error on validation failure
- Slug input (`name="team[slug]"`), monospace font, hint "Lowercase letters, numbers, and hyphens", with inline `.label-text-alt` error on validation failure
- `.btn.btn-primary` "Create Team" submit button

Components: `.card`, `.bg-base-200`, `.badge`, `.badge-primary`, `.badge-ghost`, `.btn`, `.btn-primary`, `.btn-ghost`, `.btn-sm`, `.form-control`, `.input`, `.label`, `.label-text-alt`

Responsive: Account cards stack vertically on all screen sizes; form fields stack full-width on mobile.

## Test Assertions

- renders accounts page with Your Accounts header for authenticated user
- displays account cards with name, type badge, and role badge
- highlights the active account with data-active true
- shows Switch button for inactive accounts and Active label for current account
- switches active account on switch_account click and shows success flash
- shows empty state when user has no accounts
- creates a new team account via inline form and shows success flash
- shows validation errors on create team form with invalid data
- live-validates team form fields on change
- subscribes to PubSub and refreshes account list on real-time updates
- redirects unauthenticated users to login
