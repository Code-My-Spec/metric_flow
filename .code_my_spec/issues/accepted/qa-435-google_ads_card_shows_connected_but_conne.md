# Google Ads card shows "Connected" but Connect/Reconnect button shows unsupported error

## Severity

medium

## Scope

app

## Description

On the  /integrations/connect  grid, the Google Ads card shows a "Connected" badge and a "Reconnect" button. Clicking "Reconnect" shows the flash "This platform is not yet supported" — because  google_ads  has no configured OAuth provider module, only  google  does. This creates a misleading UI: a user who has a Google Ads integration (seeded or otherwise) sees it as "Connected" but cannot reconnect it through the OAuth flow. The  authorize_url(:google_ads)  call returns  {:error, :unsupported_provider} . Reproduced at:  http://localhost:4070/integrations/connect  — click Reconnect on the Google Ads card.

## Source

QA Story 435 — `.code_my_spec/qa/435/result.md`

## Resolution

Mapped `google_ads` and `google_analytics` to the existing Google OAuth provider, since they authenticate through Google's OAuth flow.

Files changed:
- `lib/metric_flow/integrations.ex` — added `google_ads: MetricFlow.Integrations.Providers.Google` and `google_analytics: MetricFlow.Integrations.Providers.Google` to `@default_providers`

Verified: `mix compile --warnings-as-errors` clean, `mix test` passes.
