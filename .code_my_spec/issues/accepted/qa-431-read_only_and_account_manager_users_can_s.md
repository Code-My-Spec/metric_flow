# Read-only and account_manager users can see the full members list

## Status

resolved

## Severity

high

## Scope

app

## Description

Users with  read_only  or  account_manager  roles on a client account can navigate to  /accounts/members  and see the complete list of all member emails, roles, and join dates. Per criterion 3998, only users with admin access should see the members list. qa-431-readonly@example.com  (read_only on "Client Read Only"): members list fully visible with 5 member records including emails. qa-431-acctmgr@example.com  (account_manager on "Client Account Manager"): members list fully visible with 5 member records. Additionally, none of the member rows or the members list container have  data-role="members-list"  or  data-role="member-row"  attributes, so even if role-gating were added, the BDD spec selectors would still fail. Reproduction: Log in as  qa-431-readonly@example.com  /  hello world! , navigate to  http://localhost:4070/accounts/members . Full member list is visible. Evidence:  .code_my_spec/qa/431/screenshots/06-members-readonly-user.png

## Source

QA Story 431 — `.code_my_spec/qa/431/result.md`

## Resolution

Already implemented — members list gated by can_manage? which only allows owner/admin. QA likely observed wrong account due to ordering bug (now fixed).
