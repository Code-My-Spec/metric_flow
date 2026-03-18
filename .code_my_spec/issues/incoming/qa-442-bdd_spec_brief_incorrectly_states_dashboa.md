# BDD spec brief incorrectly states /dashboards/new does not exist

## Status

incoming

## Severity

low

## Scope

docs

## Description

The brief for this story ( .code_my_spec/qa/442/brief.md ) states: "There is no  /dashboards/new  route in the application." This is incorrect. The route exists and renders a fully functional "New Dashboard" editor with template selection and  [data-role='add-visualization-btn'] . The underlying assertion about the BDD spec is still valid — the BDD spec that targets chart type selection on  /dashboards/new  is testing the wrong route, since  [data-role='chart-type-selector']  lives on  /visualizations/new . But the brief's claim that the route does not exist needs to be corrected. Reproduced by navigating to  http://localhost:4070/dashboards/new  while authenticated.

## Source

QA Story 442 — `.code_my_spec/qa/442/result.md`
