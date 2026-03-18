# Members list and member rows missing data-role attributes

## Status

resolved

## Severity

medium

## Scope

app

## Description

The  AccountLive.Members  page renders the members list and member rows without  data-role="members-list"  or  data-role="member-row"  attributes. The BDD specs for criteria 3997 and 3998 assert the presence or absence of these selectors. Even for the admin user (where the members list IS correctly shown), the selectors  [data-role='members-list']  and  [data-role='member-row']  return false because the attributes do not exist in the rendered HTML. Reproduction: Log in as  qa-431-admin@example.com  /  hello world! , navigate to  /accounts/members . Inspect DOM — no  data-role  attributes on member list container or rows.

## Source

QA Story 431 — `.code_my_spec/qa/431/result.md`

## Resolution

Already implemented — data-role=members-list and data-role=member-row attributes present in AccountLive.Members template.
