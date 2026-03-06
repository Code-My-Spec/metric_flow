# "Unsupported Platform" card visible in platform grid

## Severity

medium

## Scope

app

## Description

The platform selection grid at `/integrations/connect` renders an "Unsupported Platform" card with a Connect button. Clicking it leads to an error flash. This appears to be a fixture/placeholder entry in `@canonical_platforms` that should not be rendered in the UI. Users should not see a non-functional platform card.

## Source

QA Story 434 — `.code_my_spec/qa/434/result.md`

## Triage Notes

Confirmed by code review. `@canonical_platforms` in `IntegrationLive.Connect` (line 36) includes `%{key: :unsupported_platform, name: "Unsupported Platform", description: "This integration is not yet available"}`. This entry and its corresponding `@platform_metadata` entry (line 45) should be removed — it's a test fixture that renders as a real platform card.

## Resolution

Removed the `:unsupported_platform` entry from both `@canonical_platforms` and `@platform_metadata` in `IntegrationLive.Connect`. Updated the corresponding test to send the `"connect"` event directly with a non-existent provider string instead of clicking the now-removed card.

**Files changed:**
- `lib/metric_flow_web/live/integration_live/connect.ex`
- `test/metric_flow_web/live/integration_live/connect_test.exs`

**Verification:** Clean compilation, all 20 connect LiveView tests pass.
