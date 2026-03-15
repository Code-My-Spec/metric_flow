# Ownership transfer: new owner cannot see Transfer Ownership section in settings for the transferred account

## Status

accepted

## Severity

low

## Scope

app

## Description

Following from the above issue: after successfully receiving ownership of QA Test Account,  qa-member@example.com  cannot access the Transfer Ownership section for that account via  /accounts/settings . The settings page always shows a different account (the most recently inserted one) for this user. The transfer is functional and verifiable via  /accounts , but the settings interface does not reflect the new ownership context for accounts that are not the most recently created. This is a secondary consequence of the account-selection logic in the Settings LiveView mount, but has user-visible impact: if the new owner wants to transfer ownership again or manage settings for the account they just received, they cannot do so from the settings page.

## Source

QA Story 433 — `.code_my_spec/qa/433/result.md`
