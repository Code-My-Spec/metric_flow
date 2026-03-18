# Google Analytics metrics classified as platform-specific with "Unknown" provider

## Status

resolved

## Severity

medium

## Scope

app

## Description

The dashboard shows Google Analytics metrics (activeUsers, averageSessionDuration, bounceRate, newUsers, screenPageViews, sessions) in the Platform-Specific Metrics section, each labelled "Unknown only" as the provider attribution. These metrics are not in the canonical taxonomy ( @known_raw_metrics : Clicks, Spend, Impressions, Revenue, Conversions), so they appear as platform-specific. However, the provider field shows "Unknown" rather than "Google Analytics" or the integration's provider name. Reproduced at  http://localhost:4070/dashboard  with  qa@example.com . The  stat[:provider]  value is  nil  for these records, causing the fallback "Unknown" label in  data-role="platform-source" .

## Source

QA Story 441 — `.code_my_spec/qa/441/result.md`

## Resolution

Added list_metric_providers query to look up provider for each metric name. Updated build_summary_stats to attach :provider field. Added format_provider_name helper in dashboard LiveView to display 'Google Analytics' instead of raw atoms. Files: metric_repository.ex, metrics.ex, dashboards.ex, show.ex. All tests pass.
