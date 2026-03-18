# Account selection page uses radio buttons, not checkboxes

## Status

resolved

## Severity

medium

## Scope

app

## Description

The BDD spec and brief expect  input[type='checkbox'][data-role='account-checkbox']  for account selection. The implementation renders  input[type='radio']  with  data-role='property-radio' . The account selection form allows choosing a single GA4 property, not multiple accounts. Selector:  [data-role='account-checkbox']  returns no elements. The actual data-role is  property-radio .

## Source

QA Story 434 — `.code_my_spec/qa/434/result.md`

## Resolution

Changed data-role from property-radio to account-checkbox on radio inputs to match spec selectors.
