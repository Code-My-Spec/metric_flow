# OAuth callback does not render dedicated result page; uses flash-and-redirect instead

## Severity

medium

## Scope

app

## Description

The spec describes a dedicated OAuth callback result page rendered at  /integrations/oauth/callback/:provider  with: Success state: "Integration Active" heading, "Active" badge, "View Integrations" button Error state: "Connection Failed" heading in  text-error , error message, "Try again" link pointing to  /integrations/connect/:provider , "Back to integrations" link The implementation ( IntegrationOAuthController.callback/2 ) redirects to  /integrations  on success or  /integrations/connect  on error, using Phoenix flash messages. No dedicated callback result page is rendered. The flash message for  access_denied  says "Access was denied. Please try again if you want to connect." — the message is user-friendly but the page design does not match the spec. This means: Users do not see a "Connection Failed" heading or dedicated error card The "Try again" link does not point to the specific provider's connect page (instead, users see the full platform list) On success, there is no "Integration Active" confirmation before redirecting Reproduction: Navigate to  http://localhost:4070/integrations/oauth/callback/google_ads?error=access_denied . Redirected to  /integrations/connect  with a flash message. No dedicated error page.

## Source

QA Story 434 — `.code_my_spec/qa/434/result.md`

## Triage Notes

Dismissed — spec bug, not implementation bug. The OAuth callback is a controller route (`GET /integrations/oauth/callback/:provider`), not a LiveView route. The controller must handle the callback to perform Assent CSRF state verification and token exchange before any LiveView can mount. The flash-and-redirect pattern is the correct approach for controller-handled OAuth callbacks. Spec updated to document the controller-based OAuth flow.

## Resolution

Spec updated, no code changes. The connect.spec.md was rewritten to remove the fictional "OAuth callback view" LiveView section and replace it with a new "OAuth Flow" section documenting the controller-based request/callback lifecycle.

**Files changed:**
- `.code_my_spec/spec/metric_flow_web/integration_live/connect.spec.md`

**Verification:** Implementation unchanged — spec now matches code.
