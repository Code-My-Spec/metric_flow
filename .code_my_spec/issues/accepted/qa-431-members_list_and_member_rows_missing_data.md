# Members list and member rows missing data-role attributes

## Severity

medium

## Scope

app

## Description

The  AccountLive.Members  page renders the members list and member rows without  data-role="members-list"  or  data-role="member-row"  attributes. The BDD specs for criteria 3997 and 3998 assert the presence or absence of these selectors. Even for the admin user (where the members list IS correctly shown), the selectors  [data-role='members-list']  and  [data-role='member-row']  return false because the attributes do not exist in the rendered HTML. Reproduction: Log in as  qa-431-admin@example.com  /  hello world! , navigate to  /accounts/members . Inspect DOM — no  data-role  attributes on member list container or rows.

## Source

QA Story 431 — `.code_my_spec/qa/431/result.md`

## Resolution

Added `data-role="members-list"` to the members table container div. Changed `data-role="member"` to `data-role="member-row"` on each `<tr>`. Updated test selectors to match.

Files changed:
- `lib/metric_flow_web/live/account_live/members.ex` — added/renamed data-role attributes
- `test/metric_flow_web/live/account_live/members_test.exs` — updated selectors from `member` to `member-row`

Verified: 450 account/agencies tests pass, 0 failures.
