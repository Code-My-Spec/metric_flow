# QA Result

Story 432: User or Agency Self-Revokes Access

## Status

pass

## Scenarios

### Scenario 1: Non-owner member sees Leave Account button on account settings

**Status:** pass

Logged in as `qa-member@example.com` (read_only member of QA Test Account). Navigated to `/accounts/settings`. The "Leave Account" section is visible with a warning-bordered card containing the description "Remove yourself from this account. You will lose access to all account data. This action cannot be undone." and a "Leave Account" button with `data-role="revoke-own-access"`.

Evidence: `03-member-settings-leave-button.png`

### Scenario 2: Non-owner member can click the revoke access button

**Status:** pass

Clicked the "Leave Account" button. A DaisyUI modal dialog appeared with "Cancel" and "Leave Account" confirmation buttons. Clicked "Leave Account" in the modal. The page updated to show a green success message: "Your access has been revoked. You have left the account."

Evidence: `04-leave-confirmation-modal.png`, `05-after-leave-success.png`

### Scenario 3: Confirmation prompt warns the action cannot be undone

**Status:** pass

The confirmation modal displays: "Are you sure you want to leave this account? You will lose all access." The card description also states "This action cannot be undone." User must explicitly confirm via the modal before the action proceeds.

Evidence: `04-leave-confirmation-modal.png`

### Scenario 4: After revocation, client account is removed from user account list

**Status:** pass

After leaving the account, navigated to `/accounts`. "QA Test Account" no longer appears in the accounts list. The active account automatically switched to "Client Read Only".

Evidence: `06-accounts-after-leave.png`

### Scenario 5: Owner cannot self-revoke

**Status:** pass

Logged in as `qa@example.com` (owner of QA Test Account). Navigated to `/accounts/settings`. The owner sees General Settings, Auto-Enrollment, White-Label Branding, Transfer Ownership, and Delete Account sections — but NO "Leave Account" button. The leave option is correctly hidden for account owners.

Evidence: `07-owner-settings-no-leave.png`

### Scenario 6: User cannot re-access account without new invitation

**Status:** pass

After revoking access, logged back in as `qa-member@example.com`. Navigated to `/accounts`. "QA Test Account" does not appear in the account list. The user has no way to access the account without receiving a new invitation from the owner.

Evidence: `08-member-no-qa-account.png`

## Evidence

- `03-member-settings-leave-button.png` — Settings page showing Leave Account section for non-owner member
- `04-leave-confirmation-modal.png` — DaisyUI modal confirmation dialog after clicking Leave Account
- `05-after-leave-success.png` — Success message after confirming leave action
- `06-accounts-after-leave.png` — Accounts list with QA Test Account removed
- `07-owner-settings-no-leave.png` — Owner settings page with no Leave Account option
- `08-member-no-qa-account.png` — Member accounts list after re-login, confirming no access

## Issues

None
