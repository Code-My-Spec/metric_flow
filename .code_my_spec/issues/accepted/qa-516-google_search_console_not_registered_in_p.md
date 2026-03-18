# :google_search_console not registered in @provider_names map

## Status

resolved

## Severity

low

## Scope

app

## Description

The  @provider_names  map in  MetricFlowWeb.IntegrationLive.SyncHistory  (line 20–26 of  sync_history.ex ) explicitly maps five providers:  google_ads ,  facebook_ads ,  google_analytics ,  quickbooks , and  google . The  :google_search_console  atom is absent. At runtime, an unmatched provider falls through to  derive_display_name/1 , which converts underscores to spaces and capitalizes each word — producing "Google Search Console" correctly. However, this relies on implicit string manipulation rather than an explicit entry. If the atom name ever changes (e.g.,  :gsc  or  :search_console ), the display name will silently break without a compiler warning. Recommendation: add  google_search_console: "Google Search Console"  to the  @provider_names  map to make the display name explicit and consistent with the other providers.

## Source

QA Story 516 — `.code_my_spec/qa/516/result.md`

## Resolution

Added google_search_console: "Google Search Console" to @provider_names in SyncHistory LiveView. File: lib/metric_flow_web/live/integration_live/sync_history.ex. Verified: 81 integration live tests pass.
