# Disconnect modal heading does not include platform name

## Status

resolved

## Severity

low

## Scope

app

## Description

The disconnect confirmation modal heading reads "Confirm Disconnect" rather than the spec-specified "Disconnect {Platform Name}?" pattern (e.g., "Disconnect QuickBooks?"). The modal body paragraph does include the platform name ("Are you sure you want to disconnect QuickBooks?"), but the  <h3>  heading is generic. Source:  lib/metric_flow_web/live/integration_live/index.ex , line 211 —  <h3 class="font-bold text-lg">Confirm Disconnect</h3> . Reproduced at:  http://localhost:4070/integrations , click "Disconnect" on any connected platform.

## Source

QA Story 436 — `.code_my_spec/qa/436/result.md`

## Resolution

Changed modal heading from "Confirm Disconnect" to "Disconnect {Platform Name}?" using the platform display name.

**Files changed:** `lib/metric_flow_web/live/integration_live/index.ex`
**Verification:** All 2561 tests pass.
