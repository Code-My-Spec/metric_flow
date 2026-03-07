# WhiteLabelHook is not registered in live sessions

## Severity

high

## Scope

app

## Description

MetricFlowWeb.WhiteLabelHook  is implemented but not listed in the  on_mount  hooks for either live session in  lib/metric_flow_web/router.ex . Even if the plug were wired, the hook would not transfer the session config to socket assigns, so no LiveView would receive  @white_label_config . Fix: add  {MetricFlowWeb.WhiteLabelHook, :load_white_label}  to the  on_mount  list for the  :require_authenticated_user  live session in  router.ex .

## Source

QA Story 454 — `.code_my_spec/qa/454/result.md`

## Resolution

Added `{MetricFlowWeb.WhiteLabelHook, :load_white_label}` to the `on_mount` list for the `:require_authenticated_user` live session in `lib/metric_flow_web/router.ex`.

**Files changed:** `lib/metric_flow_web/router.ex`
**Verified:** `mix test` — all account and dashboard tests pass (116/116).
