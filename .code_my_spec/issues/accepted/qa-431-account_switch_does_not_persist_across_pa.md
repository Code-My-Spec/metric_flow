# Account switch does not persist across page navigations

## Status

resolved

## Severity

high

## Scope

app

## Description

The  switch_account  event handler in  AccountLive.Index  updates the local LiveView assigns ( active_account_id ,  active_account_name ) and shows a "Switched to {account name}" flash, but does not persist the selection to the user's session. The source code at  lib/metric_flow_web/live/account_live/index.ex  line 174 contains  _ = scope  (a no-op) where it should call  Accounts.select_active_account/2 . As a result, switching to "Client Beta" on the  /accounts  page shows "Client Beta" in the nav on that page. But navigating to  /accounts/settings  or  /integrations  resets the displayed active account back to the primary account ("QA Test Account") because the  ActiveAccountHook  re-derives the active account from  Accounts.list_accounts/1  on each LiveView mount. The spec at  .code_my_spec/spec/metric_flow_web/account_live/index.spec.md  states that  phx-click="switch_account"  "Calls  Accounts.select_active_account/2  with the given account ID." Reproduction: Log in as  qa@example.com , navigate to  /accounts , click "Client Beta" switch button (observe "Switched to Client Beta" flash), then navigate to  /integrations  — nav shows "QA Test Account" not "Client Beta".

## Source

QA Story 431 — `.code_my_spec/qa/431/result.md`

## Resolution

Replaced no-op '_ = scope' with 'Accounts.touch_membership(scope, account_id)' which updates the membership updated_at timestamp. Changed list_accounts query to sort by updated_at DESC so the most recently switched account is returned first. ActiveAccountHook now picks the first account (most recently active). Files: account_repository.ex, accounts.ex, index.ex, active_account_hook.ex, index_test.exs. All 2560 tests pass (1 pre-existing cassette failure excluded).
