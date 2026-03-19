# Saved visualizations have no index page in the UI

## Status

resolved

## Severity

high

## Scope

app

## Description

After saving a visualization via the Report Generator, there is no UI page where users can browse, find, or manage their saved visualizations. The  /visualizations  route returns 404. The  /dashboards  page only lists Dashboard entities (not Visualization entities). The "My Dashboards" section shows "No dashboards yet" for the QA user even after saving a visualization. This means visualizations created via the Report Generator are effectively write-only from a user perspective — they can be saved but not retrieved or managed through the UI. The  Dashboards.list_visualizations/1  context function exists but is not wired to any LiveView. Affected routes:  /visualizations  (404),  /dashboards  (does not show visualizations).
Source:  lib/metric_flow_web/router.ex  — no  live "/visualizations"  index route defined.

## Source

QA Story 452 — `.code_my_spec/qa/452/result.md`

## Resolution

Added VisualizationLive.Index LiveView and registered the /visualizations route. Changes: (1) Created lib/metric_flow_web/live/visualization_live/index.ex — new LiveView that lists all user visualizations, supports inline delete confirmation, and links to the editor for each visualization. (2) Added live "/visualizations", VisualizationLive.Index, :index to lib/metric_flow_web/router.ex inside the :require_authenticated_user live_session. (3) Added Dashboards.delete_visualization/2 to lib/metric_flow/dashboards.ex to expose the repository delete operation through the context API boundary. Verified: all 139 visualization and dashboard LiveView tests pass; the 7 pre-existing failures in data provider and integration sync tests are unrelated.
