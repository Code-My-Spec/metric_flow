# "View in Visualizations" link points to non-existent route /visualizations

## Status

resolved

## Severity

high

## Scope

app

## Description

The save confirmation section ( [data-role="save-confirmation"] ) contains a "View in Visualizations" link that navigates to  /visualizations . This route does not exist in the router. Navigating to it produces a  Phoenix.Router.NoRouteError  (500 error page in production). The router defines  /visualizations/new  and  /visualizations/:id/edit  but no index route. The link in  report_generator.ex  line 135: <.link navigate="/visualizations" class="link block mb-3">
  View in Visualizations
</.link> After a user saves a visualization, the confirmation prompt tells them to view it — but clicking the link crashes. This breaks the save flow's happy path and could mislead users into thinking their visualization was not saved. The fix is either: (a) add a  /visualizations  index LiveView route, or (b) update the link to point to a valid existing route such as  /dashboards . Reproduced by navigating to  http://localhost:4070/visualizations  while authenticated.

## Source

QA Story 452 — `.code_my_spec/qa/452/result.md`

## Resolution

Fixed broken /visualizations route references. The router only defines /visualizations/new and /visualizations/:id/edit — there is no index route. Updated all /visualizations href/redirect references to /dashboards (a valid index route). Files changed: lib/metric_flow_web/live/visualization_live/editor.ex (cancel link and 3 post-save redirects), lib/metric_flow_web/live/ai_live/report_generator.ex (save-confirmation link), test/metric_flow_web/live/visualization_live/editor_test.exs (5 redirect/href assertions). Verified with MIX_ENV=test mix agent_test on the editor test file: 34 tests, 0 failures.
