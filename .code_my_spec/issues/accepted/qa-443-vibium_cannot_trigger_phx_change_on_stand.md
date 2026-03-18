# Vibium cannot trigger phx-change on standalone LiveView inputs

## Status

resolved

## Severity

high

## Scope

qa

## Description

The dashboard name input uses phx-change directly on an input element without a form wrapper. Vibium browser_fill/type/keys update DOM value but do not dispatch events LiveView hooks listen for. Save scenarios 11-13 could not be tested. Workaround: wrap input in a form element.

## Source

QA Story 443

## Resolution

Wrapped the dashboard name input in a `<form phx-change="validate_name" phx-submit="save_dashboard">` element. The `phx-change` attribute was moved from the bare `<input>` to the enclosing `<form>`, which is the standard Phoenix LiveView pattern. This enables both Vibium browser automation tools and standard browser behavior to correctly dispatch change events that LiveView can listen for. Updated corresponding tests to use `form/3` + `render_change/1` instead of targeting the input element directly.

**Files changed:**
- `lib/metric_flow_web/live/dashboard_live/editor.ex`
- `test/metric_flow_web/live/dashboard_live/editor_test.exs`

**Verified by:** Full test suite passes (2561 tests, 0 failures).
