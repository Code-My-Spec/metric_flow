# MetricFlowWeb.InvitationLive.Accept

Accept invitation flow. Validates an invitation token from a URL parameter and allows the recipient to accept or decline access to an account. Handles both authenticated users (who accept directly) and unauthenticated users (who are redirected to log in or register before being returned to this page).

## Type

liveview

## Route

`/invitations/:token`

## Params

- `token` - string, invitation token from the emailed invitation link

## Dependencies

- MetricFlow.Invitations
- MetricFlow.Users

## Components

None

## User Interactions

- **mount**: Reads the `token` path param and calls `Invitations.get_invitation_by_token(token)`. On success, assigns `invitation` (with preloaded account name, inviting user email, and granted role) and `page_title: "Accept Invitation"`. If the invitation is not found or has already been used, puts an error flash "This invitation link is invalid or has already been used." and redirects to `/`. If the invitation has expired, puts an error flash "This invitation has expired." and redirects to `/`. If the user is authenticated (via `current_scope`), assigns `current_user` from the scope; if unauthenticated, assigns `current_user: nil` — the template adjusts accordingly.

- **handle_params**: No-op; all state is loaded in mount via the token param.

- **phx-click="accept"**: Available only to authenticated users. Calls `Invitations.accept_invitation(scope, token)`. On `{:ok, _membership}`, puts a success flash "You now have access to [Account Name]." and redirects to `/accounts` via `push_navigate`. On `{:error, :already_member}`, puts an info flash "You already have access to this account." and redirects to `/accounts`. On `{:error, :expired}`, puts an error flash "This invitation has expired." and redirects to `/`. On `{:error, :not_found}`, puts an error flash "This invitation is no longer valid." and redirects to `/`. On `{:error, _reason}`, puts an error flash "Something went wrong. Please try again." and stays on the page.

- **phx-click="decline"**: Available only to authenticated users. Calls `Invitations.decline_invitation(scope, token)`. On `{:ok, _}`, puts an info flash "Invitation declined." and redirects to `/`. On any error, puts an error flash "Something went wrong." and stays on the page.

- **phx-click="log_in_to_accept"**: Available only to unauthenticated users. Navigates to `/users/log-in` with a `return_to` query param set to the current invitation URL (`/invitations/:token`), so after login the user is returned here to complete acceptance.

- **phx-click="register_to_accept"**: Available only to unauthenticated users. Navigates to `/users/register` with a `return_to` query param set to the current invitation URL (`/invitations/:token`), so after registration the user is returned here to complete acceptance.

## Design

Layout: Centered single-column page with the aurora background visible behind the card. The outer wrapper is `mf-content flex items-center justify-center min-h-[80vh]`.

Main content:
  - Card (`mf-card p-8 w-full max-w-md`): Contains all invitation content.
    - Header area: Account avatar placeholder (`.avatar.placeholder`, `.bg-primary.text-primary-content.rounded-full.w-14.h-14` with account initial) centered above the heading.
    - Heading: H2 "You've been invited" (`.text-xl.font-semibold.text-center`).
    - Subtext: "**[Inviting User Email]** has invited you to join **[Account Name]** as a **[Role Label]**." (`.text-sm.text-base-content/70.text-center.mt-2`). Role label is human-readable (e.g., "Admin", "Account Manager", "Read Only").
    - Divider (`.divider`).
    - Authenticated state (user is logged in):
      - Accept button (`.btn.btn-primary.w-full`, `phx-click="accept"`, `data-role="accept-btn"`): label "Accept Invitation".
      - Decline link (`.btn.btn-ghost.btn-sm.w-full.mt-2`, `phx-click="decline"`, `data-role="decline-btn"`): label "Decline".
    - Unauthenticated state (user is not logged in):
      - Info paragraph (`.text-sm.text-base-content/60.text-center.mb-4`): "Sign in or create an account to accept this invitation."
      - Log in button (`.btn.btn-primary.w-full`, `phx-click="log_in_to_accept"`, `data-role="log-in-btn"`): label "Log In to Accept".
      - Register link (`.btn.btn-ghost.btn-sm.w-full.mt-2`, `phx-click="register_to_accept"`, `data-role="register-btn"`): label "Create an Account".

Components: `.mf-card`, `.btn`, `.btn-primary`, `.btn-ghost`, `.btn-sm`, `.avatar`, `.placeholder`, `.divider`
Responsive: Card is full-width on mobile with `p-4`, and max-width `md` on larger screens. Buttons stack vertically in both layouts.
