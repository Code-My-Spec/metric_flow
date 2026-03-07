# WhiteLabel plug is not wired into the browser pipeline

## Severity

high

## Scope

app

## Description

MetricFlowWeb.Plugs.WhiteLabel  is implemented but not added to the  :browser  plug pipeline in  lib/metric_flow_web/router.ex . Without this plug, no request ever has white-label config written to the session, making subdomain-based agency branding completely non-functional. Fix: add  plug MetricFlowWeb.Plugs.WhiteLabel  to the  :browser  pipeline in  router.ex .

## Source

QA Story 454 — `.code_my_spec/qa/454/result.md`

## Resolution

Added `plug MetricFlowWeb.Plugs.WhiteLabel` as the last plug in the `:browser` pipeline in `lib/metric_flow_web/router.ex`, after `fetch_current_scope_for_user` so the session is available.

**Files changed:** `lib/metric_flow_web/router.ex`
**Verified:** `mix test` — all account and dashboard tests pass (116/116).
