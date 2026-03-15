# Empty state test for /insights requires an isolated user account

## Status

dismissed

## Severity

low

## Scope

qa

## Description

The QA brief assumed `qa-member@example.com` has no insights and can be used to test the
`[data-role='no-insights-state']` empty state at `/insights`. In practice, both
`qa@example.com` and `qa-member@example.com` resolve to the same account (account_id=2,
"QA Test Account") via `Accounts.get_personal_account_id/1`, which returns the user's first
account membership row. Both users share the team account and see the same 5 seeded insights.

The `[data-role='no-insights-state']` state could not be exercised. The application logic is
correct (conditional on `@insights == []`) — this is a test infrastructure gap.

To fix: create a seed user with no account memberships, or document that empty state testing
requires a fresh database user not added to any account that has insights.

## Source

QA Story 450 — `.code_my_spec/qa/450/result.md`
