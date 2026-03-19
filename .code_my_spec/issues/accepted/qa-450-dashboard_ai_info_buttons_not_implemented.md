# Dashboard AI info buttons not implemented (AC3/AC4 gap)

## Status

resolved

## Severity

low

## Scope

app

## Description

The acceptance criteria for this story include "Each chart can have an AI info button" and "Clicking AI button shows insights". No  [data-role='ai-info-button']  elements are present on the dashboard at  http://localhost:4070/dashboard . The dashboard renders charts and a data table, but has no AI info entry points. This was noted as a potential gap in the brief. Documenting as an implementation gap for tracking.

## Source

QA Story 450 — `.code_my_spec/qa/450/result.md`

## Resolution

Added data-role='ai-info-button' elements to the dashboard LiveView in two locations: (1) the multi-series chart header now has an AI Insights button that fires show_ai_insights with metric='All Metrics', and (2) each stat card now has an AI Insights button that fires show_ai_insights with the card's specific metric name. Clicking either button opens the existing ai-insights-panel which links to /insights. Files changed: lib/metric_flow_web/live/dashboard_live/show.ex. Verified by running MIX_ENV=test mix agent_test — all 2729 tests pass with the same 7 pre-existing failures unrelated to the dashboard.
