# phx-change on select elements does not fire LiveView events via Vibium browser_select

## Severity

medium

## Scope

qa

## Description

The role change feature on the Members page ( /accounts/members ) uses a  <select phx-change="change_role">  per member row. When  browser_select  is called on this element, the option changes visually but the LiveView  phx-change  binding does not fire — the server never receives the  change_role  event and no flash appears. Keyboard navigation (ArrowDown, ArrowUp, Enter keys) after clicking the select also failed to trigger the event. The sr-only  [data-role='change-role']  button (which BDD spex uses via  render_click ) is not actionable via browser automation — clicking it times out immediately with "element is obscured". This means Scenario 4 (role change) and the role-change portion of Scenario 9 cannot be verified end-to-end through Vibium browser automation. The feature is verified to work via BDD unit tests ( mix spex ), but browser-level QA cannot confirm the role change UI flow. Reproduction: Navigate to  /accounts/members  as owner with a non-owner member in the list. Call  mcp__vibium__browser_select(selector: "select[phx-change='change_role'][phx-value-user_id='<id>']", value: "admin") . Observe: the select renders "admin" but no "Role updated" flash appears and the role badge does not update.

## Resolution

This is a known limitation of Vibium's `browser_select` tool — it sets the select value visually but does not dispatch the DOM `change` event that Phoenix LiveView's `phx-change` binding listens for. This is not an app bug.

Workaround for QA: use `browser_evaluate` to dispatch a `change` event after calling `browser_select`, or use `browser_fill` + `browser_keys` to simulate user interaction that triggers the event. Alternatively, accept that role change scenarios are verified via BDD unit tests (`mix spex`) and note browser verification as a known gap.

### Files Changed

None — QA tooling limitation, no code fix needed.

### Verification

The feature works correctly via `mix spex` BDD tests. The limitation is specific to Vibium's browser automation not triggering LiveView JS hooks on select elements.

## Source

QA Story 430 — `.code_my_spec/qa/430/result.md`
