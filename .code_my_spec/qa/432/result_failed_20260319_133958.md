# QA Result

Story 432: User or Agency Self-Revokes Access

## Status

fail

## Scenarios

### Scenario 1: Non-owner member sees a revoke access button on account settings

**Status: FAIL**

Steps taken:
1. Ran `mix run priv/repo/qa_seeds_432.exs` to seed base data.
2. Sent an invitation to fresh user `qa-readonly@example.com` as `read_only` via `/accounts/invitations` while logged in as owner `qa@example.com`.
3. Registered `qa-readonly@example.com` at `/users/register` and confirmed via magic link from dev mailbox.
4. Navigated to the invitation URL `/invitations/wV8UQ6kL6suzRr97au-enZEjjrJHWdRLZULQjWLQQAY` and clicked "Accept Invitation" — acceptance confirmed with flash "You now have access to QA Test Account."
5. Navigated to `/accounts/settings` as `qa-readonly@example.com` (read_only member).
6. Inspected full page text and HTML.

Observation: The account settings page loaded successfully and displayed the "General Settings" section in read-only mode (account name, slug, and type with no save button). There is no "Revoke Access", "Leave Account", or any element with `data-role="revoke-own-access"` anywhere on the page. The feature has not been implemented.

Evidence: `.code_my_spec/qa/432/screenshots/03-member-account-settings.png` — full-page screenshot of the settings page for a read_only member, showing no revoke access button.
Evidence: `.code_my_spec/qa/432/screenshots/07-readonly-member-settings-no-revoke-button.png` — second full-page screenshot confirming same result.

### Scenario 2: Non-owner member can click the revoke access button

**Status: FAIL — not testable**

The `[data-role='revoke-own-access']` element does not exist in the rendered page. The revoke access feature has not been implemented in `MetricFlowWeb.AccountLive.Settings`. This scenario cannot be executed.

### Scenario 3: Confirmation prompt warns the action cannot be undone

**Status: FAIL — not testable**

Depends on Scenario 2. No revoke button exists to trigger a confirmation prompt.

### Scenario 4: After revocation, client account removed from user account list

**Status: FAIL — not testable**

Depends on Scenario 2. Revocation cannot be performed because the feature does not exist.

The member's account list was verified to show "QA Test Account" with `read_only` role before any revocation attempt.

Evidence: `.code_my_spec/qa/432/screenshots/06-readonly-member-accounts-list.png` — accounts list for `qa-readonly@example.com` showing QA Test Account and QA Readonly Personal.

### Scenario 5: Owner cannot self-revoke

**Status: PASS (partial)**

Steps taken:
1. Logged in as `qa@example.com` and navigated to `/accounts/settings`.
2. Inspected the full page HTML.

Observation: No "Revoke Access" or "Leave Account" button is visible for the owner/admin user, which is the expected behavior. The settings page shows editable General Settings (save button present), plus Auto-Enrollment and White-Label Branding sections for team account admins. No revoke-own-access element was found.

Note: `qa@example.com` currently holds `admin` role (not `owner`) on QA Test Account due to a prior ownership transfer in a previous QA session. As a result, the Transfer Ownership and Delete Account sections (which are only rendered for the `owner` role) were also absent from this session. This does not affect the revoke access test — a revoke button is absent for both owner and admin roles, as expected.

Evidence: `.code_my_spec/qa/432/screenshots/04-owner-account-settings.png` — settings page for qa@example.com (admin role) showing no revoke access button.
Evidence: `.code_my_spec/qa/432/screenshots/05-owner-accounts-page-shows-admin-role.png` — accounts list showing qa@example.com has admin role on QA Test Account.

### Scenario 6: User cannot re-access account without new invitation

**Status: FAIL — not testable**

Depends on Scenario 2. Revocation cannot be performed, so post-revocation access control cannot be verified.

## Evidence

- `.code_my_spec/qa/432/screenshots/01-dev-mailbox.png` — dev mailbox showing invitation email sent to qa-readonly@example.com
- `.code_my_spec/qa/432/screenshots/02-invitation-accept-page.png` — invitation acceptance page for qa-readonly@example.com showing the Accept Invitation button
- `.code_my_spec/qa/432/screenshots/03-member-account-settings.png` — account settings page for read_only member (first visit), no revoke access button
- `.code_my_spec/qa/432/screenshots/04-owner-account-settings.png` — account settings page for qa@example.com (admin role), no revoke access button
- `.code_my_spec/qa/432/screenshots/05-owner-accounts-page-shows-admin-role.png` — accounts list showing qa@example.com has admin role on QA Test Account
- `.code_my_spec/qa/432/screenshots/06-readonly-member-accounts-list.png` — accounts list for qa-readonly@example.com showing read_only membership in QA Test Account
- `.code_my_spec/qa/432/screenshots/07-readonly-member-settings-no-revoke-button.png` — full-page account settings for read_only member, no revoke access button (second confirmation)

## Issues

### Revoke own access feature is not implemented

#### Severity
HIGH

#### Scope
APP

#### Description
The account settings page (`/accounts/settings`) does not include any UI for a non-owner member to revoke their own access. The BDD spec for story 432 expects an element with `data-role="revoke-own-access"` on this page, and checks for text matching "Revoke Access", "Leave Account", or "revoked" — none of these are present.

The current `MetricFlowWeb.AccountLive.Settings` template only renders:
- A read-only general settings view for non-owner/non-admin roles (account name, slug, type)
- An editable general settings form for owner/admin roles
- Agency auto-enrollment and white-label sections for owner/admin roles on team accounts
- Transfer ownership and delete account sections for the account owner only

There is no "leave account" or "revoke own access" section for any role. The `Invitations` context also has no `revoke_own_access/2` or `leave_account/2` function. The feature is entirely absent from both the backend and the frontend.

All five testable acceptance criteria for this story are blocked by this missing implementation:
- User can revoke their own access from client account settings
- Confirmation prompt warns that this action cannot be undone
- After revocation, client account is removed from user account list
- Client is notified via email when user revokes their own access
- User cannot re-access account without new invitation from client

Reproduced at `http://localhost:4070/accounts/settings` as `qa-readonly@example.com` (read_only member of QA Test Account).

### qa-member@example.com has owner role on QA Test Account from prior QA sessions

#### Severity
LOW

#### Scope
QA

#### Description
The seed script `priv/repo/qa_seeds_432.exs` detected that `qa-member@example.com` already has `owner` role on QA Test Account (not `read_only` as intended). This is a side effect of prior QA sessions where ownership was transferred. The script only checks for existing membership and skips the invite/accept flow — it does not validate or correct the existing role.

As a result, `qa-member@example.com` cannot be used as the non-owner member test subject without a manual role correction or fresh user. A fresh user `qa-readonly@example.com` was registered and invited during this QA session to work around the issue.

To fix: update `qa_seeds_432.exs` to verify the role matches `read_only` on existing membership, and use `Accounts.update_user_role/4` to demote to `read_only` if needed. Alternatively, document this limitation explicitly in the seed script comments.

### return_to parameter not honored after password login for invited users

#### Severity
MEDIUM

#### Scope
APP

#### Description
When an unauthenticated user on `/invitations/:token` clicks "Log In to Accept", they are redirected to `/users/log-in?return_to=/invitations/:token`. After successfully submitting the password login form, the app redirected to `/` (home page) instead of the `return_to` URL.

Steps to reproduce:
1. Navigate to an invitation URL while not logged in (e.g., `/invitations/wV8UQ6kL6suzRr97au-enZEjjrJHWdRLZULQjWLQQAY`)
2. Click "Log In to Accept" — redirected to `/users/log-in?return_to=/invitations/...`
3. Submit the password login form with valid credentials
4. Expected: redirected back to `/invitations/...` to complete acceptance
5. Actual: redirected to `/` (home page)

The user can still manually navigate to the invitation URL after login to accept, but the intended UX flow is broken. This may be a pre-existing issue unrelated to story 432.
