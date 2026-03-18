# OAuth connect button not rendered when provider is not configured

## Status

resolved

## Severity

high

## Scope

app

## Description

On the per-platform detail view ( /integrations/connect/:provider ), the  [data-role='oauth-connect-button']  anchor is only rendered when  @authorize_url  is non-nil. In development and QA environments,  Integrations.authorize_url/1  returns  {:error, _}  for all providers (Google Ads, Facebook Ads, Google Analytics) because OAuth credentials are not configured. As a result, the Connect button is never shown — instead the page shows "Reconnect is not available — this provider is not currently configured for OAuth." This means a real user visiting the connect page in a production environment without configured OAuth credentials also sees no connect button, with no clear guidance on why. The error state should either show a more helpful message or the admin should configure OAuth before the connect flow is presented to users. Reproduced at:  http://localhost:4070/integrations/connect/google_ads  and  http://localhost:4070/integrations/connect/google_analytics

## Source

QA Story 434 — `.code_my_spec/qa/434/result.md`

## Resolution

Replaced the hidden connect button with a visible DaisyUI warning alert when OAuth is not configured: "OAuth is not configured for this provider. Please contact your administrator." The alert uses `alert-warning` styling with a warning icon so users understand why they can't connect.

**Files changed:**
- `lib/metric_flow_web/live/integration_live/connect.ex` — added `alert-warning` div when `@authorize_url` is nil

**Verification:** All 2561 tests pass.
