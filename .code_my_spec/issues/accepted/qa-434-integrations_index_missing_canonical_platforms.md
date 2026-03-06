# /integrations Available Platforms section only shows configured providers, missing canonical platforms

## Severity

medium

## Scope

app

## Description

The `/integrations` page (IntegrationLive.Index) Available Platforms section only shows providers that are already configured (e.g., just "Google" in dev), rather than the full canonical set of Google Ads, Facebook Ads, and Google Analytics. The `IntegrationLive.Connect` page correctly unions canonical platforms, but `IntegrationLive.Index.build_platform_list/0` lacks this logic. Users should see all supported platforms on the main integrations page regardless of what is configured in the current environment.

## Source

QA Story 434 — `.code_my_spec/qa/434/result.md`

## Triage Notes

Confirmed by code review. `IntegrationLive.Index.build_platform_list/0` (line 341) only calls `Integrations.list_providers()` without unioning canonical platforms. `IntegrationLive.Connect.build_platform_list/1` (line 513) correctly unions configured, canonical, and integration-based providers. The Index page needs the same canonical platform union logic.

## Resolution

Added a `@canonical_platforms` module attribute to `IntegrationLive.Index` listing Google Ads, Facebook Ads, and Google Analytics. Updated `build_platform_list/0` to union canonical platform keys with configured provider keys before mapping to display metadata, mirroring the pattern in `IntegrationLive.Connect`.

**Files changed:**
- `lib/metric_flow_web/live/integration_live/index.ex`

**Verification:** Clean compilation, all integration LiveView tests pass.
