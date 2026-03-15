# BDD spex route uses /invitations/:token/accept but actual route is /invitations/:token

## Status

accepted

## Severity

info

## Scope

qa

## Description

All seven BDD spec files for story 429 navigate to  /invitations/:token/accept  (with a trailing  /accept  segment), but the router defines the route as  /invitations/:token  with no suffix. The spex tests would fail with a no-route error when run against the live app. The actual source code and spec file ( .code_my_spec/spec/metric_flow_web/invitation_live/accept.spec.md ) document the route correctly as  /invitations/:token . The BDD spex files need their URLs updated to remove the  /accept  suffix. Affected files: test/spex/429_agency_or_user_accepts_client_invitation/criterion_3977_*.exs test/spex/429_agency_or_user_accepts_client_invitation/criterion_3978_*.exs test/spex/429_agency_or_user_accepts_client_invitation/criterion_3979_*.exs test/spex/429_agency_or_user_accepts_client_invitation/criterion_3980_*.exs test/spex/429_agency_or_user_accepts_client_invitation/criterion_3981_*.exs test/spex/429_agency_or_user_accepts_client_invitation/criterion_3982_*.exs test/spex/429_agency_or_user_accepts_client_invitation/criterion_3983_*.exs

## Source

QA Story 429 — `.code_my_spec/qa/429/result.md`
