# QuickBooks OAuth success path not implemented

## Severity

high

## Scope

app

## Description

Navigating to  /integrations/oauth/callback/quickbooks?code=test_auth_code  shows "Connection Failed" with "Could not complete the connection. Please try again." — the success path for QuickBooks OAuth is not implemented. The  Integrations.handle_callback  function cannot exchange a QuickBooks authorization code because no QuickBooks OAuth provider is configured. The acceptance criteria require: "Integration is saved only after successful OAuth completion" and "User sees confirmation that QuickBooks is connected." Neither is achievable in the current state. Reproduced at:  http://localhost:4070/integrations/oauth/callback/quickbooks?code=test_auth_code

## Source

QA Story 435 — `.code_my_spec/qa/435/result.md`

## Resolution

Created QuickBooks OAuth provider and registered it in the Integrations context.

Files changed:
- `lib/metric_flow/integrations/providers/quick_books.ex` — new QuickBooks OAuth provider using Assent.Strategy.OAuth2 with Intuit endpoints
- `lib/metric_flow/integrations.ex` — added `quickbooks: MetricFlow.Integrations.Providers.QuickBooks` to `@default_providers`
- `config/runtime.exs` — added `QUICKBOOKS_CLIENT_ID` and `QUICKBOOKS_CLIENT_SECRET` env var config

Verified: `mix compile --warnings-as-errors` clean, `mix test` passes.
