# MetricFlowWeb.AccountLive.Settings

Account settings, ownership transfer, and deletion for the active account. Owners and admins can edit account name and slug. Only owners can transfer ownership to another admin/member and delete the account. Deletion requires typing the account name for confirmation and re-entering the user's password. Personal accounts cannot be deleted. Subscribes to account PubSub for real-time updates.

## Type

liveview

## Route

`/accounts/settings`

## Params

None

## Dependencies

- MetricFlow.Accounts
- MetricFlow.Users

## Components

- AccountLive.Components.Navigation - sidebar or tab navigation with active tab indicator for the accounts section

## User Interactions

- **phx-change="validate"**: Triggered on every keystroke in the account name or slug input fields. Calls `Accounts.change_account/3` with `action: :validate` to produce live validation errors. Updates the form assign without persisting. Visible to owners and admins only.
- **phx-submit="save"**: Triggered when the owner or admin submits the settings form. Calls `Accounts.update_account/3`. On success, reassigns the updated account and shows a success flash. On validation or authorization error, reassigns the form with errors. Only visible to owners and admins.
- **phx-submit="transfer_ownership"**: Triggered when the owner submits the transfer ownership form with a selected member user ID. Calls `Accounts.update_user_role/4` twice — once to promote the target to `:owner` and once to demote the current user to `:admin`. On success, reloads the member list, updates `current_user_role`, and shows a success flash. On error, shows an error flash. Only visible to owners of team accounts.
- **phx-submit="delete_account"**: Triggered when the owner submits the deletion confirmation form. Validates the typed account name matches the actual account name exactly, then verifies the user's password via `Users.get_user_by_email_and_password/2`. On both checks passing, calls `Accounts.delete_account/2` and redirects to `/accounts` with an info flash. On name mismatch, shows error flash "Account name does not match". On wrong password, shows error flash "Incorrect password". Only visible to owners of team accounts.

## Design

Layout: Single-column, centered page with `max-w-2xl` container, wrapped in `mf-content` for correct z-index above the aurora background.

Page header: Title "Account Settings" with a subtitle showing the active account name using `text-base-content/60`.

Main content is divided into three stacked sections separated by `mf-section` dividers:

**Section 1 — General Settings** (visible to owners and admins):
  - `mf-card` panel containing a form with two fields stacked vertically using `space-y-4`
  - "Account Name" text input: `input w-full`, pre-filled with `account.name`; shows `.input-error` and an inline error message (`text-sm text-error`) when the changeset has a name error
  - "Slug" text input: `input w-full font-mono`, pre-filled with `account.slug`; shows `.input-error` and an inline error message when the changeset has a slug error; helper text below in `text-xs text-base-content/50` reads "Used in URLs. Lowercase letters, numbers, and hyphens only."
  - "Account Type" read-only `<p>` labeled with `text-sm text-base-content/60`, displaying "Personal" or "Team" — not an input field
  - `.btn .btn-primary` submit button labeled "Save Changes" aligned to the right; hidden for read-only and account_manager roles

**Section 2 — Transfer Ownership** (visible to owners of team accounts only):
  - `mf-card` panel with header "Transfer Ownership" and subtext warning in `text-sm text-base-content/60`: "The selected member will become the account owner. You will be demoted to admin."
  - `<select class="select w-full">` dropdown labeled "New Owner" — lists all non-owner account members by name and email; `data-role="transfer-ownership"` on the form element
  - `.btn .btn-warning` submit button labeled "Transfer Ownership"
  - Section is hidden (`hidden`) for non-owner roles and for personal accounts

**Section 3 — Danger Zone** (visible to owners of team accounts only):
  - `mf-card` panel with `border-error/40` border override to signal destructive context
  - Header "Delete Account" in `text-error`
  - Warning paragraph: "This action is permanent and cannot be undone. All account data, members, and integrations will be deleted."
  - Deletion confirmation form (`data-role="delete-account"`):
    - Text input labeled "Type the account name to confirm" — `input w-full`, `phx-debounce="blur"`; shows `.input-error` state when the submitted name does not match
    - Password input labeled "Your password" — `input input-password w-full`
    - `.btn .btn-error` submit button labeled "Delete Account"
  - Section is hidden (`hidden`) for non-owner roles and for personal accounts

Components: `.mf-card`, `.mf-content`, `.mf-section`, `.btn`, `.btn-primary`, `.btn-warning`, `.btn-error`, `.btn-ghost`, `.input`, `.input-error`, `.select`, `.label`, `.badge`, `.badge-ghost`

Responsive: All form sections stack full-width on mobile. The slug helper text wraps naturally. On small screens the Save Changes button spans full width (`w-full sm:w-auto`).

## Test Assertions

- renders account settings page with account name and slug fields for owner
- shows Account Type as read-only text (Personal or Team)
- live-validates account name and slug on change and shows inline errors
- saves account settings and shows success flash on valid submit
- shows unauthorized error when non-owner/admin attempts to save
- displays Transfer Ownership section for owners of team accounts
- hides Transfer Ownership section for non-owners and personal accounts
- transfers ownership to selected member and demotes current user to admin
- displays Danger Zone with delete account form for owners of team accounts
- hides Danger Zone for non-owners and personal accounts
- shows Account name does not match error when confirmation name is wrong
- shows Incorrect password error when password is wrong during deletion
- deletes account and redirects to /accounts on valid confirmation
- prevents deletion of personal accounts
- shows read-only settings view for non-editor roles
- subscribes to account PubSub and updates on real-time changes
- redirects to /accounts when user has no accounts
- shows Leave Account section for non-owner members of team accounts
- confirms and processes leave account action
