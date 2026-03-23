# OAuth callback with no parameters or invalid code redirects to grid instead of provider error view

## Status

resolved

## Severity

medium

## Scope

app

## Description

When the OAuth callback receives no parameters ( /integrations/oauth/callback/quickbooks )
or a code with no matching state ( ?code=test_auth_code ), the controller redirects to
 /integrations/connect  (the platform selection grid) with a generic flash error "Could
not complete the connection. Please try again." The  render_result/1  view with "Connection Failed" heading is only shown when the
controller redirects to  /integrations/connect/:provider  with an error flash. The
no-params and invalid-state paths do not include the provider in the redirect, so the
error view is never rendered for these cases. Users lose context of which provider failed and see a generic error on an unrelated page.
The controller should redirect to  /integrations/connect/quickbooks  (with the provider
param) even for no-params and state-mismatch errors, so the "Connection Failed" view
appears with "Try again" and "Back to integrations" links. Reproduced at: http://localhost:4070/integrations/oauth/callback/quickbooks  (no params) http://localhost:4070/integrations/oauth/callback/quickbooks?code=test_auth_code  (code, no matching state)

## Source

QA Story 435 — `.code_my_spec/qa/435/result.md`

## Resolution

Changed rescue block redirect in callback/2 from /integrations/connect to /integrations/connect/:provider so users see the provider-specific Connection Failed view. Files changed: lib/metric_flow_web/controllers/integration_oauth_controller.ex. Verified: mix compile + MIX_ENV=test mix agent_test (2705 tests, 0 failures).
