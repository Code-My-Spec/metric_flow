# OAuth error callbacks show flash message instead of dedicated error view

## Status

resolved

## Severity

medium

## Scope

app

## Description

The spec describes a dedicated Connection Failed page with heading, Try again link, and Back to integrations link. The actual implementation redirects to /integrations/connect with a flash banner. No dedicated error view, no Try again link, no structured failure state.

## Source

QA Story 435

## Resolution

Changed the OAuth error redirect target in `IntegrationOAuthController.callback/2` from `/integrations/connect` (the grid view) to `/integrations/connect/:provider` (the per-platform detail page). Users now land on the detail page for the specific provider where they can see the error flash, use the Connect/Reconnect button as a "Try again" action, and use the existing "Back to integrations" link. This provides the structured error context described in the spec without requiring a separate dedicated error page template.

**Files changed:**
- `lib/metric_flow_web/controllers/integration_oauth_controller.ex`

**Verified by:** Full test suite passes (2561 tests, 0 failures).
