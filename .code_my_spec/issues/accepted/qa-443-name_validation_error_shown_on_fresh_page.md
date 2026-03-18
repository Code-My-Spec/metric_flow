# Name validation error shown on fresh page load

## Status

resolved

## Severity

medium

## Scope

app

## Description

On /dashboards/new the name input shows a validation error immediately before any user interaction. The has_name_error helper checks changeset.errors without verifying changeset.action is set.

## Source

QA Story 443

## Resolution

Added a function clause `has_name_error?(%Ecto.Changeset{action: nil})` that returns `false`, so validation errors are only displayed after user interaction triggers the `validate_name` event (which now sets `action: :validate` on the changeset). On fresh page load the changeset has `action: nil` and no errors are shown.

**Files changed:**
- `lib/metric_flow_web/live/dashboard_live/editor.ex`

**Verified by:** Full test suite passes (2561 tests, 0 failures).
