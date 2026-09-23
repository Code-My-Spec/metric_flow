# QA Story Brief

Story 442: Flexible Chart Visualization Options

## Tool

web (vibium MCP browser tools)

## Auth

Log in using the password form. The QA seed user is `qa@example.com` with password `hello world!`.

```
mcp__vibium__browser_launch(headless: true)
mcp__vibium__browser_navigate(url: "http://localhost:4070/users/log-in")
mcp__vibium__browser_scroll(selector: "#login_form_password")
mcp__vibium__browser_fill(selector: "#login_form_password_email", text: "qa@example.com")
mcp__vibium__browser_fill(selector: "#user_password", text: "hello world!")
mcp__vibium__browser_click(selector: "#login_form_password button[name='user[remember_me]']")
mcp__vibium__browser_wait_for_url(pattern: "/", timeout: 5000)
mcp__vibium__browser_get_url()   # verify redirect landed
```

## Seeds

No story-specific seeds required. The base QA seed user (`qa@example.com`) is sufficient.

Verify the server is up and seeds exist before testing:

```bash
curl -s -o /dev/null -w "%{http_code}" http://localhost:4070/users/log-in
# Expected: 200
```

If login fails (user not found), run the base seeds:

```bash
mix run priv/repo/qa_seeds.exs
```

Note: The QA test account has no connected integrations, so `available_metrics` will be empty. The chart type selector is always rendered regardless of available metrics — testing chart type selection does not require metrics.

## Setup Notes

The BDD spec file for this story (`criterion_4076_...spex.exs`) targets `/dashboards/new` with a `data-role='add-visualization-btn'` element to open a metric picker before the chart type selector appears. However, the actual implementation lives at `/visualizations/new` (`MetricFlowWeb.VisualizationLive.Editor`). There is no `/dashboards/new` route in the application, and the chart type selector (`data-role='chart-type-selector'`) is always visible on page load at `/visualizations/new` — no button click is needed to reveal it.

Tests below target the actual implementation at `/visualizations/new`. A separate issue should be filed against the BDD spec for targeting the wrong route and interaction model.

## What To Test

### Scenario 1: Visualization editor page loads at /visualizations/new

- Navigate to `http://localhost:4070/visualizations/new` (after login)
- Expected: page renders with heading "New Visualization"
- Expected: `[data-role='chart-type-selector']` is present on the page without any additional clicks
- Screenshot: capture the full page

### Scenario 2: Chart type selector displays all three chart type options

- On the `/visualizations/new` page, locate `[data-role='chart-type-selector']`
- Expected: Three buttons are visible inside the selector — "Line", "Bar", and "Area"
- Verify text content of each button
- Screenshot: capture the chart type selector section

### Scenario 3: "Line" chart type button is present and selectable (AC: multiple chart types)

- Confirm the button with text "Line" exists in `[data-role='chart-type-selector']`
- Click the "Line" button (`[phx-click='select_chart_type'][phx-value-chart_type='line']`)
- Expected: the "Line" button gains `btn-primary` CSS class (highlighted/active state)
- Screenshot: capture the selector after selecting Line

### Scenario 4: "Bar" chart type button is present and selectable (AC: multiple chart types)

- Click the "Bar" button (`[phx-click='select_chart_type'][phx-value-chart_type='bar']`)
- Expected: the "Bar" button gains `btn-primary` CSS class
- Expected: the previously selected "Line" button loses `btn-primary` (only one active at a time)
- Screenshot: capture the selector after selecting Bar

### Scenario 5: "Area" chart type button is present and selectable (AC: multiple chart types)

- Click the "Area" button (`[phx-click='select_chart_type'][phx-value-chart_type='area']`)
- Expected: the "Area" button gains `btn-primary` CSS class
- Screenshot: capture the selector after selecting Area

### Scenario 6: Default chart type on page load is "line"

- Navigate to `/visualizations/new` fresh (or confirm the initial state)
- Expected: "Line" button has `btn-primary` class on first render (default is `line` per `handle_params`)
- Screenshot: capture initial chart type selector state

### Scenario 7: Unauthenticated access redirects to login

- Clear cookies (or use a fresh browser session without login)
- Navigate to `http://localhost:4070/visualizations/new`
- Expected: redirected to `http://localhost:4070/users/log-in`
- Screenshot: capture the login redirect

### Scenario 8: BDD spec route mismatch — /dashboards/new does not exist

- Navigate to `http://localhost:4070/dashboards/new`
- Expected: either a 404 error page or redirect — NOT the dashboard editor
- This confirms the BDD spec targets an unimplemented or non-existent route
- Screenshot: capture the response

## Result Path

`.code_my_spec/qa/442/result.md`
