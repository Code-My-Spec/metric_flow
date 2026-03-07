# Empty state test for /insights requires an isolated user account

## Severity

low

## Scope

qa

## Description

The QA brief assumed  qa-member@example.com  has no insights and can be used to test the
 [data-role='no-insights-state']  empty state. In practice both users share account_id=2
("QA Test Account") via  Accounts.get_personal_account_id/1 , which returns the first account
membership. The member user sees the same 5 seeded insights as the owner. The empty state could
not be exercised. A seed user with no account memberships is needed to test this path.

## Source

QA Story 450 — `.code_my_spec/qa/450/result.md`
