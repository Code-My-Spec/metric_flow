# No top-level /dashboard route — BDD specs reference a non-existent URL

## Severity

high

## Scope

app

## Description

The story acceptance criteria and all 8 BDD spec files navigate to  /dashboard  but this route does not exist in the application. The router only defines  GET /dashboards/:id  mounted to  MetricFlowWeb.DashboardLive.Show . Requesting  /dashboard  returns a  Phoenix.Router.NoRouteError  (HTTP 500 in dev mode). The story describes an "All Metrics dashboard" as a primary top-level feature page — it should be accessible at a stable URL like  /dashboard  or  /metrics . Requiring knowledge of a specific dashboard record  :id  contradicts the spec's intent of a unified platform-wide view. Reproduced: navigate to  http://localhost:4070/dashboard  when authenticated — 500 error with "no route found for GET /dashboard".

## Source

QA Story 441 — `.code_my_spec/qa/441/result.md`

## Resolution

Added `live "/dashboard", DashboardLive.Show, :index` route to the router, alongside the existing `/dashboards/:id` route. The `/dashboard` route renders the same LiveView with `:index` action, serving as the top-level "All Metrics" dashboard page.

Files changed:
- `lib/metric_flow_web/router.ex` — added `/dashboard` route

Verified: 182 dashboard tests pass, 0 failures.
