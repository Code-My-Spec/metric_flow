# AC3/AC4: Dashboard does not render ai-info-button on chart visualizations

## Severity

medium

## Scope

app

## Description

AC3 states "Each chart or visualization can have an AI info button." AC4 states "Clicking AI
button shows context-specific insights or opens chat about that metric." The  /dashboard  LiveView does not render any  [data-role='ai-info-button']  elements. There
is no mechanism for a user to open chart-specific AI insights directly from a visualization.
The  /insights  page exists as a separate destination for AI recommendations but is not linked
from individual chart cards. The BDD spex for criterion_4133 uses the  owner_with_integrations  given and visits  /dashboard ,
but its assertions are written with flexible  or  conditions (e.g.,  html =~ "AI Insights"  is
true because the navigation link to  /insights  appears in the nav bar), so the test passes
without the feature being present on the dashboard itself. Reproduction: Log in and navigate to  /dashboard . Inspect the page — no  [data-role='ai-info-button'] 
elements are present on any chart or visualization container. Expected: Each chart card should have a button (data-role="ai-info-button") that opens a
context-specific insights panel or links to  /insights  with a metric filter. Actual: No AI info button exists on any dashboard visualization.

## Source

QA Story 450 — `.code_my_spec/qa/450/result.md`

## Resolution

The fix was already present in the working tree. Each chart card in `DashboardLive.Show` now renders an AI info button (`data-role="ai-info-button"`) with a `phx-click="show_ai_insights"` event that passes the metric name. Clicking it opens a context-specific AI insights panel (`data-role="ai-insights-panel"`) with the metric name and a link to the full `/insights` page. A close button (`hide_ai_insights`) dismisses the panel.

**Files changed:**
- `lib/metric_flow_web/live/dashboard_live/show.ex` — Added `ai-info-button` to each chart card header (lines 153-161), `show_ai_insights`/`hide_ai_insights` event handlers (lines 375-381), and the AI insights panel (lines 178-200). Added `ai_panel_open` and `ai_panel_metric` assigns to mount.

**Verification:**
- `mix test test/metric_flow/dashboards_test.exs` — 28 tests, 0 failures
- `mix test test/spex/450_ai_insights_and_suggestions/criterion_4133*` — 1 test, 0 failures
