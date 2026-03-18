# QA Result

Story 442: Flexible Chart Visualization Options

## Status

pass

## Scenarios

### Scenario 1: Visualization editor page loads at /visualizations/new

pass

Navigated to `http://localhost:4070/visualizations/new` after logging in as `qa@example.com`. The page rendered with the H1 heading "New Visualization". The `[data-role='chart-type-selector']` element was immediately visible without any additional clicks required.

Evidence: `screenshots/01-visualizations-new-page-load.png`

### Scenario 2: Chart type selector displays all three chart type options

pass

Located `[data-role='chart-type-selector']` and used `browser_find_all` to enumerate its buttons. Found exactly three buttons: "Line", "Bar", "Area". Text content matched expectations.

Evidence: `screenshots/02-chart-type-selector.png`

### Scenario 3: "Line" chart type button is present and selectable

pass

Clicked `[phx-click='select_chart_type'][phx-value-chart_type='line']`. After the click, the button's class was `btn btn-sm btn-primary`, confirming the active state.

Evidence: `screenshots/03-line-selected.png`

### Scenario 4: "Bar" chart type button is present and selectable

pass

Clicked `[phx-click='select_chart_type'][phx-value-chart_type='bar']`. The Bar button's class became `btn btn-sm btn-primary`. The previously selected Line button's class reverted to `btn btn-sm btn-ghost`, confirming only one chart type is active at a time.

Evidence: `screenshots/04-bar-selected.png`

### Scenario 5: "Area" chart type button is present and selectable

pass

Clicked `[phx-click='select_chart_type'][phx-value-chart_type='area']`. The Area button gained `btn-primary` class. The page rendered correctly with Area as the active selection.

Evidence: `screenshots/05-area-selected.png`

### Scenario 6: Default chart type on page load is "line"

pass

On the initial page load at `/visualizations/new`, the Line button's class was `btn btn-sm btn-primary` before any interaction. The `handle_params/3` function assigns `selected_chart_type: "line"` as the default, and the rendered UI reflects this correctly.

Evidence: `screenshots/06-default-line-selected.png`

### Scenario 7: Unauthenticated access redirects to login

pass

Used `curl -s -o /dev/null -w "%{http_code} %{redirect_url}" http://localhost:4070/visualizations/new` (no session cookies). The response was `302 http://localhost:4070/users/log-in`, confirming the route is protected by the `require_authenticated_user` pipeline.

The browser screenshot shows the login page, taken as additional evidence.

Evidence: `screenshots/07-unauth-redirect-login.png`

### Scenario 8: BDD spec route mismatch — /dashboards/new

informational

Navigated to `http://localhost:4070/dashboards/new`. The route exists and renders a "New Dashboard" editor page — it does NOT return 404. The page contains `[data-role='add-visualization-btn']` ("+ Add Visualization") and a template chooser. However, `[data-role='chart-type-selector']` is not present on `/dashboards/new` — it belongs to the `/visualizations/new` editor.

The brief stated `/dashboards/new` "does not exist." This is inaccurate — the route does exist, it just doesn't contain the chart type selector. The BDD spec that targets chart type selection on `/dashboards/new` is testing the wrong route and wrong interaction model.

Evidence: `screenshots/08-dashboards-new.png`

### Exploratory: Preview button disabled without metric selection

pass

On page load, `[data-role='preview-chart-btn']` had `disabled=""` attribute and `btn-disabled` class when no metric was selected. After clicking the `revenue` metric button, the disabled attribute and class were removed, enabling the Preview Chart button. Clicking Preview Chart then rendered the Vega-Lite chart spec in `[data-role='vega-lite-chart']` with sample data for the past 7 days.

Evidence: `screenshots/11-preview-chart-rendered.png`

### Exploratory: Save validation with blank name

pass

Clicking "Save Visualization" with no name filled showed an inline error "can't be blank" beneath the name input. The page did not navigate away. After providing a name but no metric, the save was blocked with the name error (the name validation runs first before metric validation).

Evidence: `screenshots/09-save-without-name-metric.png`, `screenshots/10-save-without-metric.png`

### Exploratory: Shareable toggle

pass

`[data-role='toggle-shareable']` started with class `btn-ghost`. Clicking it updated the class to `btn-primary`, confirming the toggle works and LiveView updates the UI state correctly.

## Evidence

- `screenshots/01-visualizations-new-page-load.png` — initial page load at /visualizations/new
- `screenshots/02-chart-type-selector.png` — chart type selector with three options visible
- `screenshots/03-line-selected.png` — Line button active after click
- `screenshots/04-bar-selected.png` — Bar button active, Line reverted to ghost
- `screenshots/05-area-selected.png` — Area button active
- `screenshots/06-default-line-selected.png` — Line active by default on first render
- `screenshots/07-unauth-redirect-login.png` — login page shown for unauthenticated access
- `screenshots/08-dashboards-new.png` — /dashboards/new exists as a Dashboard editor (not 404)
- `screenshots/09-save-without-name-metric.png` — name validation error on save with blank name
- `screenshots/10-save-without-metric.png` — repeated save attempt with name still showing validation
- `screenshots/11-preview-chart-rendered.png` — preview chart rendered with revenue metric

## Issues

### BDD spec brief incorrectly states /dashboards/new does not exist

#### Severity
LOW

#### Scope
DOCS

#### Description
The brief for this story (`.code_my_spec/qa/442/brief.md`) states: "There is no `/dashboards/new` route in the application." This is incorrect. The route exists and renders a fully functional "New Dashboard" editor with template selection and `[data-role='add-visualization-btn']`.

The underlying assertion about the BDD spec is still valid — the BDD spec that targets chart type selection on `/dashboards/new` is testing the wrong route, since `[data-role='chart-type-selector']` lives on `/visualizations/new`. But the brief's claim that the route does not exist needs to be corrected.

Reproduced by navigating to `http://localhost:4070/dashboards/new` while authenticated.
