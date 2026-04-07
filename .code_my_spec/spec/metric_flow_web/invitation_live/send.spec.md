# MetricFlowWeb.InvitationLive.Send

Send email invitations to users or agencies to grant them access to the active account. Displays a send-invitation form and a list of pending invitations. Only owners and admins of the active account may access this page. Invitations are sent to any email address — the recipient does not need to have an existing account. Pending invitations can be cancelled by the inviting user, an owner, or an admin.

## Type

liveview

## Route

`/accounts/invitations`

## Params

None

## Dependencies

- MetricFlow.Invitations
- MetricFlow.Accounts

## Components

- AccountLive.Components.Navigation - sidebar or tab navigation with active tab indicator for the accounts section

## User Interactions

- **mount**: Checks that `current_scope` contains an active account. If the authenticated user's role in the active account is not `:owner` or `:admin`, redirects to `/accounts/members` with an error flash "You do not have permission to invite members." On authorized mount, calls `Invitations.list_invitations(scope, account_id)` and assigns the result to `pending_invitations`. Builds an empty invitation changeset via `Invitations.change_invitation(scope, %{})` and assigns it to `invitation_form`. Assigns `page_title: "Invite Members"`.

- **phx-change="validate"**: Triggered on every keystroke in the invite form fields. Calls `Invitations.change_invitation(scope, params)` to produce a live-validated changeset. Updates the `invitation_form` assign. Does not persist anything.

- **phx-submit="send_invitation"**: Triggered when an owner or admin submits the invite form. Calls `Invitations.send_invitation(scope, account_id, params)` with the submitted `email` and `role`. On `{:ok, _invitation}`, appends the new invitation to `pending_invitations`, resets `invitation_form` to a fresh empty changeset, and puts a success flash "Invitation sent to {email}." On `{:error, :unauthorized}`, puts an error flash "You do not have permission to send invitations." On `{:error, changeset}`, reassigns `invitation_form` with the changeset carrying field errors and shows no flash.

- **phx-click="cancel_invitation" phx-value-id**: Triggered when an owner or admin clicks the Cancel button on a pending invitation row. Calls `Invitations.decline_invitation(scope, invitation_id)` by looking up the invitation by ID from `pending_invitations` assigns, then calling `decline_invitation/2` with the invitation's token. On `{:ok, _}`, removes the cancelled invitation from `pending_invitations` and puts an info flash "Invitation to {email} cancelled." On `{:error, _}`, puts an error flash "Could not cancel invitation. Please try again."

## Design

Layout: Single-column, centered page with `max-w-3xl` container, wrapped in `mf-content`. Unauthenticated users are redirected to `/users/log-in` by the router's `require_authenticated_user` plug. Non-owner/non-admin users are redirected in mount.

Page header:
- H1 "Invite Members" in `text-2xl font-bold`
- Subtitle showing the active account name in `text-base-content/60`
- Back link (`.btn.btn-ghost.btn-sm`) labeled "Back to Members" linking to `/accounts/members`

**Send Invitation section** (`data-role="invite-form-section"`):
- `.mf-card p-6 mb-6`
- H2 "Send an Invitation" in `text-lg font-semibold mb-4`
- Description paragraph in `text-sm text-base-content/60 mb-4`: "The recipient will receive an email with a secure link. The link expires in 7 days and can only be used once."
- Form (`form[phx-submit="send_invitation"][phx-change="validate"]`, `id="invite_member_form"`):
  - Email field (`.form-control`):
    - `<label class="label">` with `label-text` "Email address"
    - `<input type="email" class="input w-full" name="invitation[email]" placeholder="colleague@example.com" phx-debounce="500">`
    - Error message (`text-sm text-error mt-1`) shown when the changeset has an email error
  - Role field (`.form-control mt-4`):
    - `<label class="label">` with `label-text` "Access level"
    - `<select class="select w-full" name="invitation[role]">` with options:
      - `value="admin"` — "Admin"
      - `value="account_manager"` — "Account Manager"
      - `value="read_only"` — "Read Only" (default selected)
    - Owner is not an option in the role select
    - Error message (`text-sm text-error mt-1`) shown when the changeset has a role error
  - Submit row (`flex justify-end mt-6`):
    - `.btn.btn-primary` submit button labeled "Send Invitation" (`data-role="submit-invite"`)

**Pending Invitations section** (`data-role="pending-invitations"`):
- Shown when `pending_invitations` is non-empty
- `.mf-card p-6`
- H2 "Pending Invitations" in `text-lg font-semibold mb-4`
- Invitation list: one row per pending invitation (`data-role="pending-invitation-row"`, `data-invitation-id="{id}"`)
  - Each row is a `flex items-center justify-between gap-4 py-3 border-b border-base-300/30 last:border-0`
  - Left side:
    - Recipient email in `font-medium` (`data-role="invitation-email"`)
    - Below email: role badge — `.badge` with role-specific color matching the members page convention: `.badge-secondary` for admin, `.badge-accent` for account_manager, `.badge-ghost` for read_only
    - Below badge: sent-at timestamp in `text-xs text-base-content/50` formatted as "Sent {relative time, e.g. 2 hours ago}"
    - Expiry indicator: `text-xs text-base-content/40` reading "Expires {absolute date}"
  - Right side:
    - `.btn.btn-ghost.btn-xs.btn-error` cancel button (`phx-click="cancel_invitation"`, `phx-value-id="{invitation.id}"`, `data-role="cancel-invitation"`) labeled "Cancel"

- Empty state (shown when `pending_invitations` is empty):
  - `.mf-card p-6` containing centered muted text: "No pending invitations." in `text-base-content/50 text-center py-4`

Components: `.mf-card`, `.mf-content`, `.btn`, `.btn-primary`, `.btn-ghost`, `.btn-sm`, `.btn-xs`, `.btn-error`, `.form-control`, `.input`, `.select`, `.label`, `.label-text`, `.badge`, `.badge-secondary`, `.badge-accent`, `.badge-ghost`, `.divider`

Responsive: Form fields and invitation rows stack to full-width on mobile. The cancel button is always visible and does not collapse. On small screens the submit button spans full width (`w-full sm:w-auto`).
