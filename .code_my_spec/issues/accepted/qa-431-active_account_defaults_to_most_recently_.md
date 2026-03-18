# Active account defaults to most-recently-joined account instead of primary account

## Status

resolved

## Severity

medium

## Scope

app

## Description

When  qa@example.com  (the agency owner) logs in, their "active" account resolves to "Client Account Manager" — the most recently created client account — rather than their own "QA Test Account". This is because  Accounts.list_accounts/1  orders by  account_members.inserted_at DESC , and the grant propagation step added qa@example.com as a member of the client accounts most recently. The account settings page shows "Client Account Manager" as the active account for the owner, and the owner has no edit form there (they have account_manager role on that account). The owner cannot easily access their own account's settings. This is a systemic issue: without an explicit account-switching mechanism (criterion 3993), users with multiple account memberships are stuck with whatever account the list ordering puts first. Reproduction: Run both seed scripts, log in as  qa@example.com , navigate to  /accounts/settings . Observe "Client Account Manager" shown as active instead of "QA Test Account". Evidence:  .code_my_spec/qa/431/screenshots/02-accounts-settings-owner.png

## Source

QA Story 431 — `.code_my_spec/qa/431/result.md`

## Resolution

Fixed — added primary_account/1 helper that prefers personal account over most-recently-joined. Updated ActiveAccountHook, AccountLive.Index/Members/Settings.
