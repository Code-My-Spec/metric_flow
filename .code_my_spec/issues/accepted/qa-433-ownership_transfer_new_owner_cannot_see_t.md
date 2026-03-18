# Ownership transfer: new owner cannot see Transfer Ownership section in settings for the transferred account

## Status

resolved

## Severity

low

## Scope

app

## Description

Following from the above issue: after successfully receiving ownership of QA Test Account,  qa-member@example.com  cannot access the Transfer Ownership section for that account via  /accounts/settings . The settings page always shows a different account (the most recently inserted one) for this user. The transfer is functional and verifiable via  /accounts , but the settings interface does not reflect the new ownership context for accounts that are not the most recently created. This is a secondary consequence of the account-selection logic in the Settings LiveView mount, but has user-visible impact: if the new owner wants to transfer ownership again or manage settings for the account they just received, they cannot do so from the settings page.

## Source

QA Story 433 — `.code_my_spec/qa/433/result.md`

## Resolution

Added `handle_params/3` to `AccountLive.Settings` so that the page can accept an optional `?account_id=` query parameter. When `account_id` is provided and the user is a member of that account, settings loads for that specific account (showing the Transfer Ownership and Danger Zone sections to owners). When no `account_id` is provided, the page falls back to `primary_account` selection (personal account first, then oldest team account).

The `mount/3` callback was refactored to store the accounts list in assigns and delegate all account-specific setup to `handle_params/3`.

- **File changed:** `lib/metric_flow_web/live/account_live/settings.ex`
- **Verified:** All 36 `AccountLive.SettingsTest` tests continue to pass. A new owner can navigate to `/accounts/settings?account_id=<id>` to directly manage the transferred account.
