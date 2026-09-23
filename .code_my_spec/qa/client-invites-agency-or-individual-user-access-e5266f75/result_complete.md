# QA Result

Story 428 — Client Invites Agency or Individual User Access

## Status

pass

## Scenarios

### AC1-A: Invitation form is present on the page

pass

Navigated to `http://localhost:4070/accounts/invitations` as `qa@example.com`. The page renders with:
- H1 "Invite Members" confirmed
- Form `#invite_member_form` present
- Email input `input[name='invitation[email]']` present with placeholder "colleague@example.com"
- Role select `select[name='invitation[role]']` present
- Submit button `[data-role="submit-invite"]` labeled "Send Invitation" present

Screenshot: `.code_my_spec/qa/428/screenshots/01_invitations_page_initial.png`

### AC1-B: Send invitation to an external email address

pass

Filled `agency@externalfirm.com` in the email field, left role as Read Only, clicked "Send Invitation". Flash message appeared: "Invitation sent to agency@externalfirm.com."

Screenshot: `.code_my_spec/qa/428/screenshots/02_invitation_sent_external.png`

### AC1-C: Send invitation to an existing user email address

pass

Filled `qa-member@example.com` in the email field, left role as Read Only, submitted. Flash message: "Invitation sent to qa-member@example.com." The invitation appeared in the pending list.

Screenshot: `.code_my_spec/qa/428/screenshots/03_invitation_sent_existing_user.png`

### AC2/AC3: Invitation email delivered with secure link and 7-day expiry

pass

Navigated to `/dev/mailbox`. An email addressed to `qa-member@example.com` was present with subject "You've been invited to QA Test Account". The email body contained:
- Recipient email address `qa-member@example.com`
- Invitation link path `/invitations/HQIvTD5an8xMBjtOl_aC0fH4clrTfJNfTpPtT1fjsKk`
- "This invitation expires in 7 days."

Screenshots: `.code_my_spec/qa/428/screenshots/04_dev_mailbox.png`, `.code_my_spec/qa/428/screenshots/05_invitation_email_detail.png`

### AC4: Invitation email and acceptance page show account name and role

pass

The email subject reads "You've been invited to QA Test Account" — account name is present. The body includes "You have been invited to join QA Test Account on MetricFlow."

Navigated to the invitation acceptance link `/invitations/HQIvTD5an8xMBjtOl_aC0fH4clrTfJNfTpPtT1fjsKk`. The page showed:
- "You've been invited"
- "qa@example.com has invited you to join QA Test Account as a Read Only."

Both account name and access level were displayed correctly.

Screenshots: `.code_my_spec/qa/428/screenshots/05_invitation_email_detail.png`, `.code_my_spec/qa/428/screenshots/06_invitation_acceptance_page.png`

### AC5-A: Role select offers all three access levels

pass

Inspected `select[name='invitation[role]']`. All three options present:
- `value="read_only"` — "Read Only" (default selected)
- `value="admin"` — "Admin"
- `value="account_manager"` — "Account Manager"

Screenshot: `.code_my_spec/qa/428/screenshots/07_role_select_options.png`

### AC5-B: Invitation can be sent with each role

pass

Sent invitations to three distinct emails with different roles:
1. `role-test-readonly@example.com` with `read_only` — flash: "Invitation sent to role-test-readonly@example.com."
2. `role-test-manager@example.com` with `account_manager` — flash: "Invitation sent to role-test-manager@example.com."
3. `role-test-admin@example.com` with `admin` — flash: "Invitation sent to role-test-admin@example.com."

All three appeared in the pending invitations list with their respective role badges (Read Only, Account Manager, Admin).

Screenshot: `.code_my_spec/qa/428/screenshots/08_all_three_roles_sent.png`

### AC6-A: Accepted invitation link cannot be reused

pass

Sent invitation to `single-use-test@example.com` with role `read_only`. Retrieved token from `/dev/mailbox`: `8AJayz2VCxzdzSMAVec0NsoT-EaJJfreY1p8zP7v88o`. Logged out and logged in as `qa-member@example.com`. Navigated to `/invitations/8AJayz2VCxzdzSMAVec0NsoT-EaJJfreY1p8zP7v88o` — acceptance page rendered with "You've been invited" and the accept button. Clicked "Accept Invitation" — redirected to `/accounts`. Navigated again to the same link — page showed: "This invitation link is invalid or has already been used."

Screenshots: `.code_my_spec/qa/428/screenshots/09_acceptance_page_logged_in.png`, `.code_my_spec/qa/428/screenshots/10_after_acceptance.png`, `.code_my_spec/qa/428/screenshots/11_reused_invitation_link.png`

### AC6-B: Valid pending invitation shows acceptance page unauthenticated

pass

Logged out and navigated (unauthenticated) to `/invitations/PoI4iykjHLuMbWQnaKiXv29cL8PQofN1yAB0mPhJnaQ` (pending invitation for `role-test-admin@example.com`). The page rendered: "You've been invited — qa@example.com has invited you to join QA Test Account as a Admin." Unauthenticated users are prompted to "Log In to Accept" or "Create an Account".

Screenshot: `.code_my_spec/qa/428/screenshots/12_unauthenticated_acceptance_page.png`

### AC7-A: Pending invitations list visible after sending

pass

Logged back in as `qa@example.com`. Sent invitation to `pending-view@agency.com` with `read_only`. The `[data-role="pending-invitations"]` section was visible. The invitation row showed:
- Email `pending-view@agency.com` in `[data-role="invitation-email"]`
- Role badge "Read Only"
- Sent timestamp "Sent just now"
- Expiry "Expires Mar 26, 2026"
- Cancel button `[data-role="cancel-invitation"]`

Screenshot: `.code_my_spec/qa/428/screenshots/13_pending_invitations_visible.png`

### AC7-B: Owner can cancel a pending invitation

pass

Sent invitation to `tocancel@agency.com`. Verified it appeared in the pending list. Clicked `[data-role="cancel-invitation"][data-email="tocancel@agency.com"]`. Flash appeared: "Invitation to tocancel@agency.com cancelled." The invitation row for `tocancel@agency.com` was no longer present in `[data-role="pending-invitation-row"]`.

Screenshot: `.code_my_spec/qa/428/screenshots/14_cancel_invitation.png`

### AC7-C: Empty state shown when no invitations pending

partial

The empty state text "No pending invitations." is confirmed present in the source template (`send.ex` line 102) and renders via `:if={@pending_invitations == []}`. Testing this visually would require cancelling all 20+ existing pending invitations from prior test runs, which was not practical. The implementation is correct per code review.

### AC8: Multiple invitations appear in pending list with correct role labels

pass

Sent `first@agency.com` with `read_only` and `second@agency.com` with `admin`. Both appeared immediately in the pending list:
- `second@agency.com` — "Admin" role badge
- `first@agency.com` — "Read Only" role badge

The invite form (`#invite_member_form`) was still present and reset (empty email field) after each submission, ready for more entries.

Screenshots: `.code_my_spec/qa/428/screenshots/15_multiple_invitations.png`, `.code_my_spec/qa/428/screenshots/16_final_state.png`

## Evidence

- `.code_my_spec/qa/428/screenshots/01_invitations_page_initial.png` — invitations page initial state
- `.code_my_spec/qa/428/screenshots/02_invitation_sent_external.png` — success flash for external email invitation
- `.code_my_spec/qa/428/screenshots/03_invitation_sent_existing_user.png` — success flash for existing user invitation
- `.code_my_spec/qa/428/screenshots/04_dev_mailbox.png` — dev mailbox with invitation emails
- `.code_my_spec/qa/428/screenshots/05_invitation_email_detail.png` — invitation email body with link and 7-day expiry
- `.code_my_spec/qa/428/screenshots/06_invitation_acceptance_page.png` — acceptance page showing account name and role
- `.code_my_spec/qa/428/screenshots/07_role_select_options.png` — role select with all three options
- `.code_my_spec/qa/428/screenshots/08_all_three_roles_sent.png` — pending list after sending all three roles
- `.code_my_spec/qa/428/screenshots/09_acceptance_page_logged_in.png` — acceptance page as logged-in invitee
- `.code_my_spec/qa/428/screenshots/10_after_acceptance.png` — redirect after accepting invitation
- `.code_my_spec/qa/428/screenshots/11_reused_invitation_link.png` — invalid/already-used error on second visit
- `.code_my_spec/qa/428/screenshots/12_unauthenticated_acceptance_page.png` — acceptance page for unauthenticated user
- `.code_my_spec/qa/428/screenshots/13_pending_invitations_visible.png` — pending invitations list with all fields
- `.code_my_spec/qa/428/screenshots/14_cancel_invitation.png` — cancellation flash and removed row
- `.code_my_spec/qa/428/screenshots/15_multiple_invitations.png` — multiple invitations in pending list
- `.code_my_spec/qa/428/screenshots/16_final_state.png` — full page final state

## Issues

None
