# Confirm button in disconnect modal labeled "Confirm" instead of "Disconnect"

## Status

resolved

## Severity

low

## Scope

app

## Description

The spec and brief both specify the confirmation button text should be "Disconnect". The actual button renders "Confirm". The button has the correct  data-role="confirm-disconnect"  and  phx-click="disconnect"  handler, but the visible label does not match the spec. Source:  lib/metric_flow_web/live/integration_live/index.ex  —  <button ... class="btn btn-error">Confirm</button> . Reproduced at:  http://localhost:4070/integrations , click "Disconnect" on any connected platform to open the modal.

## Source

QA Story 436 — `.code_my_spec/qa/436/result.md`

## Resolution

Changed confirm button label from 'Confirm' to 'Disconnect' in index.ex
