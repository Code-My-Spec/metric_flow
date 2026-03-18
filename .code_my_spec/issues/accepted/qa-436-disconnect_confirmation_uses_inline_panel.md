# Disconnect confirmation uses inline panel instead of modal overlay

## Status

resolved

## Severity

medium

## Scope

app

## Description

The spec ( index.spec.md ) describes the disconnect confirmation as a  .modal  overlay. The brief tests for  [class*='modal-open'] . The actual implementation renders an  inline collapsible panel  ( [data-role='disconnect-warning'] ) inside the integration card rather than a DaisyUI modal. No  [class*='modal-open']  element is ever present. The inline panel does work correctly (appears on disconnect click, dismissed by Cancel, executes disconnect on Confirm), but the UX differs from the spec design which calls for a modal overlay. Reproduced at:  http://localhost:4070/integrations , click "Disconnect" on any connected integration card.

## Source

QA Story 436 — `.code_my_spec/qa/436/result.md`

## Resolution

Replaced the inline collapsible panel with a proper DaisyUI modal overlay (`<dialog class="modal modal-open">`) with `data-role="disconnect-modal"`. The modal includes a `modal-box` with confirmation message, provider name, Cancel/Confirm buttons, and a `modal-backdrop` for click-outside dismissal. Existing event handlers unchanged — modal visibility driven by the `@disconnecting` assign.

**Files changed:**
- `lib/metric_flow_web/live/integration_live/index.ex` — replaced inline panel with DaisyUI modal

**Verification:** All 2561 tests pass.
