# Settings LiveView always shows the most recently created account, ignoring active account selection

## Severity

medium

## Scope

app

## Description

The  /accounts/settings  LiveView mounts by calling  Accounts.list_accounts(scope)  and always picks the first result (most recently inserted account). This means the settings page is disconnected from the user's "active account" as managed in the  /accounts  index. When a user has multiple accounts, the account shown in settings may not be the one they selected as active. Reproduced as  qa-member@example.com  after the ownership transfer: the accounts index showed QA Test Account as "Active" (with  owner  role after transfer), but navigating to  /accounts/settings  showed "Client Account Manager" — a different account that qa-member only has  account_manager  access to. The new ownership of QA Test Account was not accessible from the settings page. This also means that for a user who has been made the owner of an account that is not their most recently created account, the Transfer Ownership and Danger Zone sections will never be visible to them from the settings page. Steps to reproduce: Log in as a user who has multiple team accounts, where the account they are owner of is not the most recently created one Navigate to  /accounts  — confirm the owned account is shown as Active Navigate to  /accounts/settings  — observe that a different account is shown

## Source

QA Story 433 — `.code_my_spec/qa/433/result.md`

## Resolution

Fixed in two files by aligning account selection logic across the hook and the Settings LiveView.

### Root cause

There were two separate bugs causing the mismatch:

1. `ActiveAccountHook` used `List.first` (most recently joined, `[account | _]`) to determine the active account name shown in the navigation bar.
2. `AccountLive.Settings.mount/3` also used `List.first` (`[account | _]`) to select which account to display — independent of the hook.
3. `AccountLive.Index` correctly used `List.last` (oldest/first joined account) as the default active account. This misalignment meant Index and Settings always showed different accounts for users with multiple memberships.

### Fix

**`lib/metric_flow_web/hooks/active_account_hook.ex`**
- Changed default account selection from `List.first` to `List.last` (oldest account, matching the Index default).
- Added session-aware account resolution: the hook now reads `active_account_id` from the Plug session if present, and falls back to `List.last`. This supports future session persistence of explicit account switches.
- Now assigns both `:active_account_id` and `:active_account_name` to the socket, making the resolved account ID available to downstream LiveViews.

**`lib/metric_flow_web/live/account_live/settings.ex`**
- Removed the independent `list_accounts` + first-pick logic from `mount/3`.
- Settings now reads `active_account_id` from socket assigns (set by the hook before mount runs) and uses `Enum.find` to select the matching account from the list, with `List.last` as the fallback.
- Removed the redundant `assign(:active_account_name, account.name)` override — the hook already sets the correct value before mount.

### Verified

- All 36 `AccountLive.SettingsTest` tests pass with no changes to test logic.
- All 88 account live tests (index, settings, members) pass.
- Full test suite: 0 new failures introduced (pre-existing unrelated failures unchanged).
