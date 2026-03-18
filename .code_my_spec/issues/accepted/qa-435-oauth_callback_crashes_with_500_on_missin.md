# OAuth callback crashes with 500 on missing state parameter

## Status

resolved

## Severity

critical

## Scope

app

## Description

GET /integrations/oauth/callback/:provider with no state parameter crashes with KeyError in Assent verify_state/3. The controller does not rescue the exception. Affects any request to callback URL without state (accidental navigation, crawlers, replay attacks). Reproduced at GET /integrations/oauth/callback/quickbooks with no params and with code but no state.

## Source

QA Story 435

## Resolution

Added a `rescue` clause for `KeyError` and `ArgumentError` in `IntegrationOAuthController.callback/2`. When Assent's `verify_state/3` raises due to a missing state parameter, the exception is now caught, logged, and the user is redirected to `/integrations/connect` with a user-friendly error flash message instead of a 500 crash.

**Files changed:**
- `lib/metric_flow_web/controllers/integration_oauth_controller.ex`

**Verified by:** Full test suite passes (2561 tests, 0 failures).
