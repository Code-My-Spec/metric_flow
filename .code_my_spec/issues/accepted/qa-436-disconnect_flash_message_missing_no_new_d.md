# Disconnect flash message missing "no new data will sync" phrase

## Status

resolved

## Severity

low

## Scope

app

## Description

After confirming a disconnect, the flash message reads "Disconnected from Google. Historical data is retained." The spec (index.spec.md) describes the flash as "Disconnected from {platform name}. Historical data is retained; no new data will sync after disconnecting." and the brief (Scenario 12) also expects the additional "No new data will sync after disconnecting." phrase. The message is truncated — the second sentence is missing. Reproduced at  http://localhost:4070/integrations  — click Disconnect on any connected platform, then confirm. Source:  lib/metric_flow_web/live/integration_live/index.ex  line 327 —  "Disconnected from #{platform_display_name(socket.assigns.platforms, provider)}. Historical data is retained." .

## Source

QA Story 436 — `.code_my_spec/qa/436/result.md`

## Resolution

Updated flash message to include "; no new data will sync after disconnecting." after "Historical data is retained".

**Files changed:** `lib/metric_flow_web/live/integration_live/index.ex`
**Verification:** All 2561 tests pass.
