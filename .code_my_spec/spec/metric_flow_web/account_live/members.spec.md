# MetricFlowWeb.AccountLive.Members

Manage account members and permissions for the active account. Displays all members with their roles and join dates. Owners and admins can change member roles, remove members, and invite new users. Enforces authorization via `Accounts.Authorization` — only owners/admins see management controls. Protects the last owner from removal or demotion. Subscribes to member PubSub for real-time updates.

## Type

liveview

## Route

`/accounts/members`

## Params

None

## Dependencies

- MetricFlow.Accounts

## Components

## User Interactions

- **phx-click="change_role"**: Triggered when an owner or admin selects a new role from the role dropdown on a member row. Calls `Accounts.update_user_role/4`. On success, reloads the member list and shows a success flash. On error (e.g., demoting the last owner), shows an error flash. Only visible to owners and admins.
- **phx-click="remove_member"**: Triggered when an owner or admin clicks the remove button on a member row. Calls `Accounts.remove_user_from_account/3`. On success, reloads the member list and shows a success flash. Hidden for the last owner row and for the current user's own row. Only visible to owners and admins.
- **phx-submit="invite_member"**: Triggered when an owner or admin submits the invite form with an email address and role. Looks up the user by email, then calls `Accounts.add_user_to_account/4`. On success, reloads the member list, shows a success flash, and clears the form. On error (user not found, already a member), shows an error flash. Only visible to owners and admins.

## Design

Layout: Single-column, centered page with `max-w-4xl` container.

Page header: Title "Members" with a subtitle showing the active account name.

Main content:
  - Card: Members table listing all account members
    - Table columns: Avatar/initials, Name and Email, Role (badge), Joined date, Actions (owners/admins only)
    - Each row has `data-role="member"` attribute
    - Role column uses `.badge` with role-specific color: `.badge-primary` for owner, `.badge-secondary` for admin, `.badge-accent` for account_manager, `.badge-ghost` for read_only
    - Actions column (owners/admins only): role change `<select>` dropdown and `.btn .btn-ghost .btn-xs .btn-error` remove button
    - Remove button is hidden for the last owner row and for the current user's own row
    - Members with read_only or account_manager role see no Actions column
  - Card (owners/admins only): Invite member form
    - Email input field labeled "Email address"
    - Role select dropdown with options: admin, account_manager, read_only (owner is not selectable)
    - `.btn .btn-primary` submit button labeled "Invite"

Components: `.card`, `.card-body`, `.table`, `.badge`, `.badge-primary`, `.badge-secondary`, `.badge-accent`, `.badge-ghost`, `.btn`, `.btn-primary`, `.btn-ghost`, `.btn-xs`, `.btn-error`, `.form-control`, `.input`, `.select`, `.label`

Responsive: Table scrolls horizontally on mobile via `overflow-x-auto`. Invite form fields stack vertically on small screens.

## Test Assertions

- renders members page with member list for owner
- displays member email, role badge, and join date in each row
- shows role change dropdown and remove button for owners and admins
- hides management controls for read_only and account_manager roles
- owner can change a member role and sees success flash
- shows error when attempting to demote the last owner
- owner can remove a member and sees success flash
- hides remove button for the last owner row
- hides remove button for the current user row
- owner can invite a new member by email and sees success flash
- shows error when inviting a non-existent user
- shows error when inviting an already existing member
- subscribes to member PubSub and refreshes on real-time updates
- redirects to /accounts when user has no accounts
