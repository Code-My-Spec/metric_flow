# QA Result

Story 428 — Client Invites Agency or Individual User Access

## Status

fail

## Scenarios

### AC1-A — Invitation form renders correctly on page load

**Result: fail**

Navigated to `http://localhost:4070/accounts/invitations` as `qa@example.com`. The page loads and renders:
- Page title "Invite Members" displayed
- Form `#invite_member_form` present
- Email input `input[name='invitation[email]']` present
- Role select `select[name='invitation[role]']` present
- Submit button `[data-role="submit-invite"]` labeled "Send Invitation" present

However, the form shows "can't be blank" validation errors for both the email and role fields on the initial page load, before the user has interacted with anything. This is a bug — validation errors should not appear until after first submission or blur. See Issues section.

Screenshot: `screenshots/01-invitations-page-initial.png`, `screenshots/02-form-validation-errors-on-load.png`

### AC1-B — Send invitation to an external email address

**Result: pass**

Filled `agency@externalfirm.com` into the email field, left role as Read Only, clicked Send Invitation. The flash message "Invitation sent to agency@externalfirm.com." appeared immediately and the invitation appeared in the pending list with correct email and role badge.

Screenshot: `screenshots/03-invitation-sent-external-email.png`

### AC1-C — Send invitation to an existing user email address

**Result: pass**

Filled `qa-member@example.com` into the email field, left role as Read Only, clicked Send Invitation. Flash message "Invitation sent to qa-member@example.com." appeared. The invitation appeared in the pending list.

Screenshot: `screenshots/04-invitation-sent-existing-user.png`

### AC2/AC3 — Invitation email delivered with secure link and 7-day expiry

**Result: pass**

Checked the dev mailbox at `/dev/mailbox` after sending an invitation to `qa-member@example.com`. Found:
- Email addressed to `qa-member@example.com`
- Subject: "You've been invited to QA Test Account" (contains "invited")
- Body contains `qa-member@example.com` (personalised with recipient address)
- Body contains link path matching `/invitations/QB3X9BXbz-efJeKVMJRfUWEM8w-QwAQBIYNO_ATgr4Q`
- Body states "This invitation expires in 7 days."

All AC2 and AC3 requirements met.

Screenshot: `screenshots/05-dev-mailbox.png`, `screenshots/06-invitation-email-content.png`

### AC4 — Acceptance page shows account name and access level

**Result: pass**

Sent an invitation to `ac4test@example.com` with role `admin`. Retrieved token `luUSWm4J6ajsCteCU2BYcjOGOCNoTKjadVwa20vsApo` from the dev mailbox. Navigated to `http://localhost:4070/invitations/luUSWm4J6ajsCteCU2BYcjOGOCNoTKjadVwa20vsApo`.

The acceptance page renders with:
- Text "You've been invited"
- "qa@example.com has invited you to join QA Test Account as a Admin."
- "QA Test Account" is present — account name shown
- "Admin" is present — access level shown
- Accept and Decline buttons present

Note: The email subject contains "QA Test Account" as expected for this seed environment. The BDD spec's SharedGivens uses "Owner Account" as the account name but the QA seed uses "QA Test Account" — both are correct relative to their context.

Screenshot: `screenshots/07-invitation-acceptance-page.png`

### AC5 — Role select offers all three access levels and each can be submitted

**Result: pass**

Verified the role select (`select[name='invitation[role]']`) contains:
- `option[value='read_only']` — "Read Only"
- `option[value='account_manager']` — "Account Manager"
- `option[value='admin']` — "Admin"

Successfully sent invitations with all three roles:
- `readonly@agency.com` with `read_only` — flash "Invitation sent to readonly@agency.com."
- `manager@agency.com` with `account_manager` — flash "Invitation sent to manager@agency.com."
- `ac4test@example.com` with `admin` — flash "Invitation sent to ac4test@example.com."

All three invitations appeared in the pending list with correct role badges (`.badge-ghost` for Read Only, `.badge-accent` for Account Manager, `.badge-secondary` for Admin).

Screenshot: `screenshots/14-multiple-invitations-pending.png`, `screenshots/16-role-options-visible.png`

### AC6-A — Accepted invitation link is invalidated after acceptance

**Result: fail**

Navigated to the acceptance page for token `luUSWm4J6ajsCteCU2BYcjOGOCNoTKjadVwa20vsApo`, clicked "Accept Invitation". The app redirected to `/accounts`. Then navigated back to the same invitation URL.

Expected: redirect with flash error "invalid or has already been used".
Actual: the acceptance page rendered again showing "Accept Invitation" and "Decline" buttons, with no indication the invitation had already been accepted.

Clicking "Accept Invitation" a second time redirected to `/accounts` with the flash "You already have access to this account." — this is a graceful fallback, but the fundamental issue is that the acceptance page renders for an already-accepted invitation instead of rejecting it at the route level.

Additionally, `ac4test@example.com`'s invitation still shows as "pending" in the `/accounts/invitations` list even after being accepted — the pending list is not updated when the invitee accepts.

Screenshots: `screenshots/09-accepted-link-reused.png`, `screenshots/10-accepted-link-second-attempt.png`, `screenshots/18-accepted-invitation-still-shows.png`

### AC6-B — Valid pending invitation link shows the acceptance page

**Result: pass**

Navigated to a valid pending invitation URL (`/invitations/QB3X9BXbz-efJeKVMJRfUWEM8w-QwAQBIYNO_ATgr4Q`). The acceptance page rendered correctly with "You've been invited", account name, access level, Accept and Decline buttons.

Screenshot: `screenshots/15-valid-pending-invitation-acceptance-page.png`

### AC7-A — Pending invitations section visible after sending

**Result: pass**

After sending an invitation, the `[data-role="pending-invitations"]` section appeared showing the new invitation in a `[data-role="pending-invitation-row"]` with:
- Recipient email in `[data-role="invitation-email"]`
- Role badge (correct colour per role)
- "Sent just now" relative timestamp
- "Expires Mar 17, 2026" expiry date
- Cancel button `[data-role="cancel-invitation"]`

Screenshot: `screenshots/11-pending-invitations-list.png`

### AC7-B — Owner can cancel a pending invitation

**Result: pass**

Sent invitation to `tocancel@agency.com`, then clicked the Cancel button (`[data-role="cancel-invitation"][data-email="tocancel@agency.com"]`). The invitation was immediately removed from the pending list and the flash message "Invitation to tocancel@agency.com cancelled." appeared.

Screenshot: `screenshots/12-invitation-cancelled.png`

### AC7-C — Cancelled invitation link is invalidated

**Result: fail**

After cancelling the `tocancel@agency.com` invitation, retrieved its token `Cf-1va6x-j_Mxhtu1dAdnwjbXQ79ngReeXjxONQsTrc` from the dev mailbox. Navigated to `/invitations/Cf-1va6x-j_Mxhtu1dAdnwjbXQ79ngReeXjxONQsTrc`.

Expected: redirect with flash error "invalid or has already been used".
Actual: redirected to `/` (home page) with no flash error message. No indication was given to the user that the invitation was invalid or cancelled. Same behaviour observed for completely bogus tokens (e.g., `/invitations/invalid-token-xyz`).

Screenshots: `screenshots/13-cancelled-invitation-redirect.png`, `screenshots/17-cancelled-link-no-flash-error.png`

### AC8 — Client can invite multiple users with different access levels

**Result: pass**

Sent two successive invitations from the same session:
1. `readonly@agency.com` with role `read_only`
2. `manager@agency.com` with role `account_manager`

Both appeared in the pending invitations list simultaneously with their correct roles. The invite form reset and remained available for additional entries after each submission. Role badges in the list correctly showed "Read Only" (`.badge-ghost`) and "Account Manager" (`.badge-accent`).

Screenshot: `screenshots/14-multiple-invitations-pending.png`

## Evidence

- `screenshots/01-invitations-page-initial.png` — initial page load showing form and pre-existing invitation
- `screenshots/02-form-validation-errors-on-load.png` — "can't be blank" errors shown on fresh form load
- `screenshots/03-invitation-sent-external-email.png` — success flash after sending to external email
- `screenshots/04-invitation-sent-existing-user.png` — success flash after sending to existing user
- `screenshots/05-dev-mailbox.png` — dev mailbox showing delivered invitation emails
- `screenshots/06-invitation-email-content.png` — invitation email body with link and 7-day expiry
- `screenshots/07-invitation-acceptance-page.png` — acceptance page showing account name and Admin role
- `screenshots/08-invitation-accepted-redirect.png` — redirect to /accounts after accepting invitation
- `screenshots/09-accepted-link-reused.png` — accepted link still renders acceptance page (bug)
- `screenshots/10-accepted-link-second-attempt.png` — second accept attempt shows "You already have access"
- `screenshots/11-pending-invitations-list.png` — pending invitations section with email, role, timestamps
- `screenshots/12-invitation-cancelled.png` — invitation removed from list with cancellation flash
- `screenshots/13-cancelled-invitation-redirect.png` — cancelled token redirects to / with no flash
- `screenshots/14-multiple-invitations-pending.png` — multiple invitations with different roles in list
- `screenshots/15-valid-pending-invitation-acceptance-page.png` — valid pending invitation acceptance page
- `screenshots/16-role-options-visible.png` — role select showing all three options
- `screenshots/17-cancelled-link-no-flash-error.png` — cancelled link redirect with no error flash
- `screenshots/18-accepted-invitation-still-shows.png` — accepted invitation still shows in pending list

## Issues

### Validation errors shown on invitation form before user interacts

#### Severity
MEDIUM

#### Description
When navigating to `/accounts/invitations`, the invite form immediately shows "can't be blank" validation errors on both the email field and the role field, before the user has typed anything or submitted the form. This creates a confusing UX — the form appears pre-errored on arrival.

Reproduced on initial page load as `qa@example.com` at `http://localhost:4070/accounts/invitations`. The HTML shows `<p class="text-sm text-error mt-1">can't be blank</p>` rendered in both field wrappers with an empty changeset on mount.

Root cause: `Invitations.change_invitation(scope, %{})` is being called with an empty params map that triggers validation — likely because the changeset runs `validate_required` on every `change_invitation` call regardless of whether it was user-triggered.

Expected: no errors on initial mount, errors only after first submission attempt or field blur.

### Accepted invitation link is not invalidated — acceptance page re-renders after use

#### Severity
HIGH

#### Description
After an invitee accepts an invitation, visiting the same invitation URL again renders the acceptance page as if the invitation were still pending. The "Accept Invitation" button is shown and can be clicked again.

Steps to reproduce:
1. Send an invitation to any email address
2. Visit the acceptance URL `/invitations/{token}`
3. Click "Accept Invitation" — redirected to `/accounts`
4. Navigate back to the same URL
5. Observation: the acceptance page renders again with "Accept Invitation" button

The second click of Accept shows flash "You already have access to this account." and redirects — so there is a guard at the acceptance logic level. However the check does not happen at the route/mount level — the acceptance page always renders for any valid token, even already-accepted ones.

Additionally, accepted invitations continue to appear in the owner's `/accounts/invitations` pending list, which means the pending count/list does not reflect the true state after acceptance.

Expected behaviour (per AC6 and BDD spec):
- Visiting an accepted invitation URL should redirect with flash error "This invitation is invalid or has already been used."
- The invitation should be removed from the pending list after acceptance.

### Cancelled and invalid invitation tokens redirect with no error flash

#### Severity
MEDIUM

#### Description
Visiting an invitation URL whose token corresponds to a cancelled invitation, or any completely invalid token, redirects to `/` (the home page) with no flash message of any kind. The user receives no feedback explaining why the link didn't work.

Tested tokens:
- `Cf-1va6x-j_Mxhtu1dAdnwjbXQ79ngReeXjxONQsTrc` — cancelled invitation for `tocancel@agency.com`
- `invalid-token-xyz` — completely bogus token

Both redirect silently to `/`.

Expected behaviour (per AC6 and BDD spec):
- Redirect should include a flash error: "This invitation is invalid or has already been used." (for cancelled/used)
- Or for expired: "This invitation has expired."

The BDD spec checks `flash["error"] =~ "invalid or has already been used"` but no such flash is set.
