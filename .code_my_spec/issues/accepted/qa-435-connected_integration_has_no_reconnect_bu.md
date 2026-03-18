# Connected integration has no Reconnect button when provider is unconfigured

## Status

resolved

## Severity

medium

## Scope

app

## Description

On the per-platform detail page, the Reconnect button only renders when authorize_url is non-nil. If a provider (e.g. google_ads) has an existing integration but is not configured as an OAuth provider, the page shows Connected with no button to reconnect. Users cannot refresh OAuth credentials from the UI.

## Source

QA Story 435

## Resolution

Added a conditional message in `render_platform_detail/1` that renders when an integration exists but `@authorize_url` is nil. The message reads "Reconnect is not available -- this provider is not currently configured for OAuth." This informs users why the Reconnect button is absent instead of showing a connected status with no action available.

**Files changed:**
- `lib/metric_flow_web/live/integration_live/connect.ex`

**Verified by:** Full test suite passes (2561 tests, 0 failures).
