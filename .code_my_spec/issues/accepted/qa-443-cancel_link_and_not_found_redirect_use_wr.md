# Cancel link and not-found redirect use wrong path /dashboards

## Status

resolved

## Severity

high

## Scope

app

## Description

The Cancel link in DashboardLive.Editor and the not-found redirect in handle_params both navigate to /dashboards (plural) which does not exist. The actual route is /dashboard (singular). Both produce Phoenix.Router.NoRouteError.

## Source

QA Story 443

## Resolution

Changed the Cancel link `navigate` target and the not-found redirect path in `DashboardLive.Editor` from `/dashboards` (plural, non-existent route) to `/dashboard` (singular, the actual route for `DashboardLive.Show :index`). Updated corresponding test assertions in `editor_test.exs`.

**Files changed:**
- `lib/metric_flow_web/live/dashboard_live/editor.ex`
- `test/metric_flow_web/live/dashboard_live/editor_test.exs`

**Verified by:** Full test suite passes (2561 tests, 0 failures).
