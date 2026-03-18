# OAuth callback is a controller redirect, not a LiveView result page

## Status

resolved

## Severity

medium

## Scope

app

## Description

The spec ( connect.spec.md ) describes the OAuth callback as a LiveView at  /integrations/oauth/callback/:provider  that renders either a "Integration Active" success view or a "Connection Failed" error view with dedicated navigation links ("View Integrations", "Try again", "Back to integrations"). The actual implementation uses  IntegrationOAuthController  which immediately redirects to  /integrations/connect/:provider  with a flash message. As a result: There is no transient "Connecting your account..." loading state There is no "Integration Active" confirmation page with "View Integrations" button There is no dedicated "Connection Failed" error page with "Try again" link Error feedback is a flash banner on the detail page, not a full error view The spec describes a better UX than what is implemented. The redirect-with-flash approach works functionally but does not meet the design specification. Reproduced at:  http://localhost:4070/integrations/oauth/callback/google_ads?error=access_denied  (redirects to  /integrations/connect/google_ads  with flash)

## Source

QA Story 434 — `.code_my_spec/qa/434/result.md`

## Resolution

Added a `:result` view mode to the connect LiveView that detects flash messages from the OAuth controller redirect. A `detect_result_state/1` function pattern-matches on flash content to determine the result:
- Success flash → "Integration Active" confirmation page with "View Integrations" button
- Error flash → "Connection Failed" error page with "Try again" and "Back to integrations" links
- No flash → normal detail view

The OAuth controller still handles the redirect (required for session-based Assent state verification), but now the LiveView renders dedicated result pages matching the spec.

**Files changed:**
- `lib/metric_flow_web/live/integration_live/connect.ex` — added `:result` view mode, `render_result/1`, and `detect_result_state/1`

**Verification:** All 2561 tests pass.
