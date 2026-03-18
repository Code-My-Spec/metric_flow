# AccountLive.Index does not display agency access level or origination status badges

## Status

resolved

## Severity

high

## Scope

app

## Description

The  /accounts  page renders all accounts the user is a member of but shows only a hardcoded "Owner" badge and the user's own email as "Originator" for every card. The implementation does not call  MetricFlow.Agencies  context functions, does not distinguish between own accounts and client accounts accessed via agency grants, and does not render access level badges ("Admin", "Account Manager", "Read Only") or origination status badges ("Originator", "Invited"). All accounts the user is an AccountMember of appear identically regardless of their actual role or relationship type. Criteria 3992 and 3999 fail entirely. Reproduction: Log in as  qa@example.com , navigate to  http://localhost:4070/accounts . Observe "Client Alpha" (agency admin, originator) and "Client Beta" (agency admin, invited) are displayed identically. Source:  lib/metric_flow_web/live/account_live/index.ex

## Source

QA Story 431 — `.code_my_spec/qa/431/result.md`

## Resolution

Already implemented — AccountLive.Index renders agency access level and origination status badges via Agencies.find_agency_grant_for_account/3.
