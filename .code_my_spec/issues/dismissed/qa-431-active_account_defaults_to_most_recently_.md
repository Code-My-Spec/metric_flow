# Active account defaults to most-recently-joined account instead of primary account

## Severity

medium

## Scope

app

## Disposition

Dismissed — merged into qa-431-accountlive_index_missing_switch_account_.md. The root cause is the absence of an explicit account-switching mechanism (criterion 3993). The ordering issue is a symptom, not a separate bug.

## Description

When  qa@example.com  (the agency owner) logs in, their "active" account resolves to "Client Account Manager" — the most recently created client account — rather than their own "QA Test Account". This is because  Accounts.list_accounts/1  orders by  account_members.inserted_at DESC , and the grant propagation step added qa@example.com as a member of the client accounts most recently.

## Source

QA Story 431 — `.code_my_spec/qa/431/result.md`
