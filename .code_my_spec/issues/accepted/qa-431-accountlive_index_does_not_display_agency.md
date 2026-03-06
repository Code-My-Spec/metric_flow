# AccountLive.Index does not display agency access level or origination status badges

## Severity

high

## Scope

app

## Description

The  /accounts  page renders all accounts the user is a member of but shows only a hardcoded "Owner" badge and the user's own email as "Originator" for every card. The implementation does not call  MetricFlow.Agencies  context functions, does not distinguish between own accounts and client accounts accessed via agency grants, and does not render access level badges ("Admin", "Account Manager", "Read Only") or origination status badges ("Originator", "Invited"). All accounts the user is an AccountMember of appear identically regardless of their actual role or relationship type. Criteria 3992 and 3999 fail entirely. Reproduction: Log in as  qa@example.com , navigate to  http://localhost:4070/accounts . Observe "Client Alpha" (agency admin, originator) and "Client Beta" (agency admin, invited) are displayed identically. Source:  lib/metric_flow_web/live/account_live/index.ex

## Source

QA Story 431 — `.code_my_spec/qa/431/result.md`

## Resolution

Mount now calls `load_account_metadata/2` which queries the actual member role per account via `Accounts.get_user_role/3` and looks up any `AgencyClientAccessGrant` per account via `Agencies.find_agency_grant_for_account/3`. The template renders actual role badges and, when a grant exists, access_level and origination_status badges.

Files changed:
- `lib/metric_flow_web/live/account_live/index.ex` — template and mount updated
- `lib/metric_flow/agencies.ex` — added `find_agency_grant_for_account/3`
- `lib/metric_flow/agencies/agencies_repository.ex` — added `find_grant_for_user_client_account/2`

Verified: 450 account/agencies tests pass, 0 failures.
