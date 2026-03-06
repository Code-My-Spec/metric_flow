# AccountLive.Index missing switch-account controls and data-role attributes

## Severity

high

## Scope

app

## Description

The accounts page has no  [data-role="switch-account"]  elements, no  phx-click="switch_account"  event handler, no  data-role="account-card"  attributes on cards, and no  data-active  attribute on cards. The account context switching feature (criterion 3993) is entirely absent. The spec at  .code_my_spec/spec/metric_flow_web/account_live/index.spec.md  documents these as required: each account card should have  data-role="account-card"  and a  [data-role="switch-account"]  button. None of these are implemented. Reproduction: Log in, navigate to  /accounts . Inspect DOM — no  data-role  attributes on account cards.

Additionally, without an explicit account-switching mechanism, users with multiple account memberships are stuck with whatever account the list ordering puts first. When qa@example.com (the agency owner) logs in, their "active" account resolves to "Client Account Manager" (the most recently created client account) rather than their own "QA Test Account", because Accounts.list_accounts/1 orders by account_members.inserted_at DESC. The owner cannot easily access their own account's settings.

(Merged from: qa-431-active_account_defaults_to_most_recently_.md)

## Source

QA Story 431 — `.code_my_spec/qa/431/result.md`

## Resolution

Added `active_account_id` tracking in assigns, defaulting to the oldest account. Each card now has `data-role="account-card"`, `data-account-id`, and `data-active` attributes. Added `handle_event("switch_account", ...)` that updates the active account and shows an info flash. Each card has a switch/active button with `data-role="switch-account"`.

Files changed:
- `lib/metric_flow_web/live/account_live/index.ex` — template, mount, and new event handler

Verified: 450 account/agencies tests pass, 0 failures.
