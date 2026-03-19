# QA Result

Story 433 — Transfer Account Ownership

## Status

partial

## Scenarios

### Scenario A — Owner sees Transfer Ownership section

**Result: pass**

Logged in as `qa@example.com` (account owner) and navigated to `http://localhost:4070/accounts/settings`. The page loaded without error and showed the QA Test Account settings. The Transfer Ownership section was present and visible:

- `[data-role='transfer-ownership']` element found and visible in the DOM (`browser_is_visible` returned `true`)
- The form contained a "New Owner" select dropdown listing non-owner account members: `qa-member@example.com`, `newuser@testco-qa.com`, `employee@readonlydomain.com`
- The "Transfer Ownership" submit button (`btn btn-warning`) was visible and enabled

Evidence: `screenshots/owner_sees_transfer_section.png` (full-page)

### Scenario B — Non-owner member does NOT see Transfer Ownership section

**Result: pass**

Logged out as owner and logged in as `qa-member@example.com`. `qa-member` already had membership in QA Test Account with role `read_only`, and in "Client Account Manager" with role `account_manager` (not owner, not admin on either account at time of test).

Navigated to `http://localhost:4070/accounts/settings`. The page loaded and showed "Client Account Manager" settings (the most recently inserted account for qa-member, per the Settings LiveView's `list_accounts` first-account selection logic).

- `[data-role='transfer-ownership']` element not present in DOM (`browser_is_visible` returned `false`)
- No "Transfer Ownership" heading or button in page text
- The page showed only the General Settings read-only section (no Save Changes button), confirming `@can_edit` is false for the `account_manager` role

Evidence: `screenshots/member_no_transfer_section.png` (full-page)

**Note:** The Settings LiveView always mounts with the first account returned by `Accounts.list_accounts(scope)`, which is the most recently created account. For qa-member this is "Client Account Manager" (a higher-id account), not QA Test Account. The non-owner test is valid because qa-member is not an owner on any account they can view in settings from the current active session.

### Scenario C — Owner performs ownership transfer

**Result: pass (transfer succeeds) with observation**

Logged back in as `qa@example.com`. Navigated to `http://localhost:4070/accounts/settings`. Selected `qa-member@example.com` (user_id=6) from the "New Owner" dropdown within `[data-role='transfer-ownership']`. Clicked the "Transfer Ownership" button.

- The page responded with a flash message: "Ownership transferred successfully"
- The Transfer Ownership section was no longer visible in the page after the transfer (confirmed with `browser_is_visible` returning `false`)
- The Save Changes button remained, confirming qa@example.com was demoted to admin (not removed)
- The Agency sections (Auto-Enrollment, White-Label) remained visible, consistent with admin role on a team account

After transfer, logged in as `qa-member@example.com` and navigated to `/accounts`. The accounts list confirmed:
- QA Test Account: role `owner` (transfer successful)
- Transfer badge shows the role correctly

However, when navigating to `/accounts/settings`, the page displayed "Client Account Manager" (not QA Test Account), because the Settings LiveView selects the first account from `list_accounts` by insertion order, which is "Client Account Manager" (more recently created). The Transfer Ownership section was not visible on that page because qa-member is not the owner of "Client Account Manager".

The transfer itself is mechanically correct and verifiable from the accounts list page. The settings page does not surface the new ownership for a user who has multiple accounts where the transferred account is not the most recently created one.

Evidence:
- `screenshots/owner_before_transfer.png` — owner view before transfer
- `screenshots/transfer_ownership_success.png` — success flash after transfer
- `screenshots/new_owner_accounts_list.png` — qa-member's accounts list showing `owner` role on QA Test Account
- `screenshots/new_owner_settings_wrong_account.png` — settings page showing wrong account for new owner

### Scenario D — Unauthenticated access redirects

**Result: pass**

```
curl -s -o /dev/null -w "%{http_code}" http://localhost:4070/accounts/settings
# Result: 302
```

Unauthenticated GET to `/accounts/settings` returns HTTP 302, redirecting to the login page. Auth protection is working correctly.

## Evidence

- `screenshots/owner_settings_page.png` — owner's settings page on initial load
- `screenshots/owner_sees_transfer_section.png` — full-page view confirming Transfer Ownership section visible to owner
- `screenshots/member_settings_default_account.png` — member's initial view (first load after login)
- `screenshots/member_no_transfer_section.png` — member settings page with no Transfer Ownership section
- `screenshots/owner_before_transfer.png` — owner's settings page before initiating transfer
- `screenshots/transfer_ownership_success.png` — success flash "Ownership transferred successfully", Transfer Ownership section gone from previous owner's view
- `screenshots/new_owner_accounts_list.png` — accounts list confirming qa-member now has `owner` role on QA Test Account
- `screenshots/new_owner_settings_wrong_account.png` — settings page showing Client Account Manager instead of QA Test Account for the new owner

## Issues

### Settings LiveView always shows the most recently created account, ignoring active account selection

#### Severity
MEDIUM

#### Scope
APP

#### Description
The `/accounts/settings` LiveView mounts by calling `Accounts.list_accounts(scope)` and always picks the first result (most recently inserted account). This means the settings page is disconnected from the user's "active account" as managed in the `/accounts` index. When a user has multiple accounts, the account shown in settings may not be the one they selected as active.

Reproduced as `qa-member@example.com` after the ownership transfer: the accounts index showed QA Test Account as "Active" (with `owner` role after transfer), but navigating to `/accounts/settings` showed "Client Account Manager" — a different account that qa-member only has `account_manager` access to. The new ownership of QA Test Account was not accessible from the settings page.

This also means that for a user who has been made the owner of an account that is not their most recently created account, the Transfer Ownership and Danger Zone sections will never be visible to them from the settings page.

**Steps to reproduce:**
1. Log in as a user who has multiple team accounts, where the account they are owner of is not the most recently created one
2. Navigate to `/accounts` — confirm the owned account is shown as Active
3. Navigate to `/accounts/settings` — observe that a different account is shown

### Ownership transfer: new owner cannot see Transfer Ownership section in settings for the transferred account

#### Severity
LOW

#### Scope
APP

#### Description
Following from the above issue: after successfully receiving ownership of QA Test Account, `qa-member@example.com` cannot access the Transfer Ownership section for that account via `/accounts/settings`. The settings page always shows a different account (the most recently inserted one) for this user. The transfer is functional and verifiable via `/accounts`, but the settings interface does not reflect the new ownership context for accounts that are not the most recently created.

This is a secondary consequence of the account-selection logic in the Settings LiveView mount, but has user-visible impact: if the new owner wants to transfer ownership again or manage settings for the account they just received, they cannot do so from the settings page.
