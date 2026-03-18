# Disconnect warning paragraph missing data-role attribute

## Status

resolved

## Severity

low

## Scope

app

## Description

The brief (Scenario 10) checks for  [data-role='disconnect-warning']  to verify the warning message is present. The actual modal body uses a plain  <p>  tag with no  data-role  attribute. The warning text itself is correct and fully present, but the element is not identifiable by the specified selector. Source:  lib/metric_flow_web/live/integration_live/index.ex , line 212-215 — the  <p class="py-4">  element has no  data-role . The fix is to add  data-role="disconnect-warning"  to the  <p>  element.

## Source

QA Story 436 — `.code_my_spec/qa/436/result.md`

## Resolution

Added `data-role="disconnect-warning"` to the `<p>` element in the disconnect modal.

**Files changed:** `lib/metric_flow_web/live/integration_live/index.ex`
**Verification:** All 2561 tests pass.
