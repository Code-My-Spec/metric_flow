# AccountLive.Index missing switch-account controls and data-role attributes

## Status

resolved

## Severity

high

## Scope

app

## Description

The accounts page has no  [data-role="switch-account"]  elements, no  phx-click="switch_account"  event handler, no  data-role="account-card"  attributes on cards, and no  data-active  attribute on cards. The account context switching feature (criterion 3993) is entirely absent. The spec at  .code_my_spec/spec/metric_flow_web/account_live/index.spec.md  documents these as required: each account card should have  data-role="account-card"  and a  [data-role="switch-account"]  button. None of these are implemented. Reproduction: Log in, navigate to  /accounts . Inspect DOM — no  data-role  attributes on account cards.

## Source

QA Story 431 — `.code_my_spec/qa/431/result.md`

## Resolution

Already implemented — data-role=account-card, data-active, data-role=switch-account with phx-click=switch_account handler all present.
