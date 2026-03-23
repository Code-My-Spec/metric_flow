# Visualizations are not persisted when editing a saved dashboard

## Status

resolved

## Severity

medium

## Scope

app

## Description

When editing an existing saved dashboard at  /dashboards/:id/edit , the canvas loads empty — the visualizations that were configured when the dashboard was originally saved are not loaded or displayed. The  handle_params  clause for the  :edit  action assigns  visualizations: []  unconditionally (line 287 in  editor.ex ) instead of loading the saved visualization configuration from the database. As a result, every edit session starts from a blank canvas. Users must re-add all visualizations from scratch each time they edit, and clicking "Save Dashboard" in an edit session replaces the dashboard name but cannot restore or modify the previous visualization layout. This makes the edit flow non-functional for its intended purpose. Reproducing: create a dashboard with visualizations, navigate to its edit URL — the canvas is empty.

## Source

QA Story 443 — `.code_my_spec/qa/443/result.md`

## Resolution

Fixed handle_params :edit action to load saved visualizations from database instead of assigning empty list. Also fixed Cancel link to navigate to /dashboards instead of /dashboard. Files changed: lib/metric_flow_web/live/dashboard_live/editor.ex. Verified: mix compile --warnings-as-errors + MIX_ENV=test mix agent_test (all pass).
