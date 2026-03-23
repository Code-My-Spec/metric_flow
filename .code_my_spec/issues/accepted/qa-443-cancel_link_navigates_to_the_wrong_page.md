# Cancel link navigates to the wrong page

## Status

resolved

## Severity

low

## Scope

app

## Description

The Cancel link in the dashboard editor header ( <.link navigate="/dashboard">Cancel</.link>  in  editor.ex  line 67) navigates to  /dashboard , which is the main analytics metrics view (charts, data table, AI insights). Users editing or creating a custom report would expect Cancel to return them to the custom reports list at  /dashboards . The not-found redirect in  handle_params  (line 302) also uses  redirect(to: "/dashboard") . While this is less critical (any redirect on not-found is acceptable), it is inconsistent with where users would expect to land. Reproduced by navigating to  http://localhost:4070/dashboards/new  while logged in and clicking "Cancel" — the browser navigated to  /dashboard  (the analytics view) instead of  /dashboards  (the custom reports list).

## Source

QA Story 443 — `.code_my_spec/qa/443/result.md`

## Resolution

Fixed Cancel link to navigate to /dashboards instead of /dashboard. Also fixed not-found redirect. File changed: lib/metric_flow_web/live/dashboard_live/editor.ex.
