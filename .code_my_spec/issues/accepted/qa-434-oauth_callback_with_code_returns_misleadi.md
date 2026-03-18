# OAuth callback with code returns misleading error "This platform is not yet supported"

## Status

resolved

## Severity

medium

## Scope

app

## Description

Visiting  http://localhost:4070/integrations/oauth/callback/google_ads?code=test_auth_code&state=test_state  results in the flash error "This platform is not yet supported" on the resulting detail page. Google Ads is a supported platform — the actual failure is that the OAuth token exchange fails because the dev environment has no real Google Ads credentials. The error originates from  format_oauth_error/2  matching the  :unsupported_provider  error reason returned by  handle_oauth_callback/4  when the provider argument is nil. However, in this code path  provider  is not nil — the error comes from  Integrations.handle_callback/4  failing the token exchange and returning  {:error, :unsupported_provider}  or similar. The message "This platform is not yet supported" should be reserved for genuinely unsupported providers; token exchange failures should show a more accurate error like "Could not complete the connection. Please try again."

## Source

QA Story 434 — `.code_my_spec/qa/434/result.md`

## Resolution

Updated `format_oauth_error/2` in the OAuth controller to distinguish between genuinely unsupported providers and token exchange failures. Token exchange failures now return "Could not complete the connection. Please try again." while `:unsupported_provider` is reserved for actually unsupported providers.

**Files changed:**
- `lib/metric_flow_web/controllers/integration_oauth_controller.ex` — updated error message mapping
- `lib/metric_flow/integrations.ex` — ensured `handle_callback/4` returns distinct error reasons

**Verification:** All 2561 tests pass.
