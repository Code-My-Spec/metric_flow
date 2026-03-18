# Save button on Edit Accounts page missing data-role='save-account-selection'

## Status

accepted

## Severity

low

## Scope

app

## Description

The BDD spec for criterion 4036 checks for  [data-role='save-account-selection']  on the edit accounts page ( /integrations/connect/google/accounts ). The page renders a  <button type="submit">  labeled "Save Selection" but it has no  data-role  attribute. The functional behavior is correct but the spec attribute is missing, which would cause the automated BDD test to fail.

## Source

QA Story 436 — `.code_my_spec/qa/436/result.md`
