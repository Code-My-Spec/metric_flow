# google_business and google_business_reviews missing from @provider_names map

## Status

resolved

## Severity

low

## Scope

app

## Description

lib/metric_flow_web/live/integration_live/sync_history.ex  defines  @provider_names  with explicit display names for  google_ads ,  facebook_ads ,  google_analytics ,  google_search_console ,  quickbooks , and  google . The new Story 517 providers  :google_business  and  :google_business_reviews  are absent from this map. They fall through to  derive_display_name/1  which produces "Google Business" and "Google Business Reviews" — both acceptable — but all other active providers are explicitly enumerated. The map should be updated to include the new providers for consistency and to avoid silent fallthrough for future name changes.

## Source

QA Story 517 — `.code_my_spec/qa/517/result.md`

## Resolution

Added google_business and google_business_reviews to @provider_names map in sync_history.ex.
