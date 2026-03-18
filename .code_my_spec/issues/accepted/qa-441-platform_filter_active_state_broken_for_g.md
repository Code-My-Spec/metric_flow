# Platform filter active state broken for :google provider

## Status

resolved

## Severity

medium

## Scope

app

## Description

Clicking the "Google" platform filter button ( phx-value-platform="google" ) on the dashboard does not update the button active state. "All Platforms" retains its  btn-primary  class and the "Google" button remains  btn-ghost , as if the  selected_platform  assign was not updated to  :google . By contrast, clicking "Google Ads" ( phx-value-platform="google_ads" ) correctly activates that button and deactivates "All Platforms". The issue likely lies in the  filter_platform  event handler:  String.to_existing_atom("google")  may fail if  :google  atom does not exist in the BEAM atom table at the time of the event (returning an exception that silently resets the socket), or  Dashboards.get_dashboard_data/2  raises when given  platform: :google , and Phoenix swallows the error without updating assigns. Reproduced: log in as  qa@example.com , navigate to  /dashboards/1 , click "Google" platform button — "All Platforms" button remains active with  btn-primary  class.

## Source

QA Story 441 — `.code_my_spec/qa/441/result.md`

## Resolution

Fixed — normalize :google to [:google_analytics, :google_ads] in Dashboards context before querying Metrics. Updated MetricRepository to support list providers.
