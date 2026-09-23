# QA Story Brief

Story 443: Create and Save Custom Reports — Dashboard Editor (`MetricFlowWeb.DashboardLive.Editor`)

## Tool

web (vibium MCP browser tools — LiveView page)

## Auth

Log in as the QA owner user via the password form:

```
mcp__vibium__browser_launch(headless: true)
mcp__vibium__browser_navigate(url: "http://localhost:4070/users/log-in")
mcp__vibium__browser_scroll(selector: "#login_form_password")
mcp__vibium__browser_fill(selector: "#login_form_password_email", text: "qa@example.com")
mcp__vibium__browser_fill(selector: "#user_password", text: "hello world!")
mcp__vibium__browser_click(selector: "#login_form_password button[name='user[remember_me]']")
mcp__vibium__browser_wait_for_url(pattern: "/", timeout: 5000)
mcp__vibium__browser_get_url()   # verify — should be http://localhost:4070/
```

## Seeds

The base QA seeds create the `qa@example.com` user and a "QA Test Account". Verify they are in place by checking login succeeds — no additional seed run is needed if login works.

The metric picker requires at least one metric record for the user. The base seeds do NOT create metrics. Run the following Elixir snippet to insert two test metrics for the QA user:

```bash
cd /Users/johndavenport/Documents/github/metric_flow

# Only run if Phoenix server is NOT already running:
mix run priv/repo/qa_seeds.exs

# Insert test metrics for qa@example.com (run from project root):
mix run --no-start -e "
  Application.ensure_all_started(:postgrex)
  Application.ensure_all_started(:ecto)
  {:ok, _} = MetricFlow.Repo.start_link([])
  import Ecto.Query
  user = MetricFlow.Repo.one!(from u in MetricFlow.Users.User, where: u.email == ^\"qa@example.com\")
  yesterday = Date.add(Date.utc_today(), -1)
  for {name, type, provider} <- [{\"sessions\", \"traffic\", :google_analytics}, {\"clicks\", \"advertising\", :google_ads}] do
    existing = MetricFlow.Repo.one(from m in MetricFlow.Metrics.Metric, where: m.user_id == ^user.id and m.metric_name == ^name)
    unless existing do
      MetricFlow.Repo.insert!(%MetricFlow.Metrics.Metric{
        user_id: user.id, metric_name: name, metric_type: type,
        value: 100.0, recorded_at: DateTime.new!(yesterday, ~T[00:00:00], \"Etc/UTC\"),
        provider: provider, dimensions: %{}
      })
    end
  end
  IO.puts(\"Metrics seeded.\")
"
```

If the seed command fails due to the Phoenix server already running (Cloudflare GenServer conflict), skip the metric seed and note in the result that the metric picker will show the empty state ("No metrics available") during testing — still proceed with all other scenarios using templates instead of manual metric selection.

## What To Test

### Scenario 1: Unauthenticated access is blocked

- Navigate to `http://localhost:4070/dashboards/new` WITHOUT logging in (use a fresh browser or clear cookies first).
- Expected: redirected to `/users/log-in` (not shown the editor).
- Capture a screenshot of the redirect/login page.

### Scenario 2: New Dashboard editor page loads for authenticated user

- After logging in, navigate to `http://localhost:4070/dashboards/new`.
- Expected: page loads with heading "New Dashboard", a "Dashboard Name" input field (`data-role="dashboard-name-input"`), a "Save Dashboard" button (`data-role="save-dashboard-btn"`), and a "Cancel" link pointing to `/dashboards`.
- Capture a screenshot of the initial editor page.

### Scenario 3: Template chooser is shown on the blank new-dashboard page

- On `http://localhost:4070/dashboards/new` with no visualizations added.
- Expected: template chooser section (`data-role="template-chooser"`) is visible with text "Start from a template or blank canvas", template cards for "Marketing Overview" and "Financial Summary", and a "Blank Canvas" card (`data-role="template-card-blank"`).
- Capture a screenshot showing the template chooser.

### Scenario 4: Selecting a template populates the canvas

- On `http://localhost:4070/dashboards/new`, click the "Marketing Overview" template card (`data-role="template-card-marketing_overview"`).
- Expected: visualization cards (`data-role="visualization-card"`) appear on the canvas; the empty canvas state (`data-role="empty-canvas"`) disappears; the template chooser also disappears (canvas is no longer empty); the selected template card shows a `ring-2 ring-primary` highlight.
- Capture a screenshot showing the populated canvas after template selection.

### Scenario 5: "+ Add Visualization" button opens the metric picker

- On `http://localhost:4070/dashboards/new`, click the "+ Add Visualization" button (`data-role="add-visualization-btn"`).
- Expected: metric picker panel (`data-role="metric-picker"`) appears with title "Add Visualization", a metric list (`data-role="metric-list"`), chart type selector (`data-role="chart-type-selector"`) with Line / Bar / Area buttons, and a "Add to Dashboard" confirm button (`data-role="confirm-add-btn"`) that is disabled.
- If no metrics are seeded: the metric list shows "No metrics available. Connect a platform to get started."
- Capture a screenshot of the open metric picker.

### Scenario 6: Closing the metric picker without adding a visualization

- With the metric picker open, click the close button (`data-role="close-metric-picker"`).
- Expected: the metric picker panel disappears; canvas state is unchanged.
- Capture a screenshot confirming the picker is closed.

### Scenario 7: Adding a visualization manually via the metric picker (if metrics are seeded)

Skip this scenario if no metrics were seeded — note the skip in the result.

- Click "+ Add Visualization", then click the "sessions" metric button in the metric list.
- Expected: the "sessions" button gains `btn-primary` styling; the "Add to Dashboard" confirm button becomes enabled (no longer has `disabled` attribute).
- Click a chart type (e.g., "Bar") — expected: the Bar button gains `btn-primary` styling.
- Click "Add to Dashboard".
- Expected: the picker closes; a visualization card (`data-role="visualization-card"`) appears showing "sessions" and a chart type badge; the empty canvas state is gone; the template chooser is gone.
- Capture a screenshot showing the new visualization card on the canvas.

### Scenario 8: Removing a visualization from the canvas

- With at least one visualization card on the canvas (added via template or manual picker), click the remove button (aria-label "Remove") on that card.
- Expected: the visualization card disappears; if it was the last card, the empty canvas state (`data-role="empty-canvas"`) reappears.
- Capture a screenshot after removal.

### Scenario 9: Reordering visualizations (move up / move down)

- With two or more visualization cards on the canvas (use the "Marketing Overview" template to get multiple cards), note the order of the first two cards.
- Click the "Move down" button (aria-label "Move down") on the first card.
- Expected: the first and second cards swap positions in the DOM.
- Click the "Move up" button (aria-label "Move up") on what is now the second card (formerly first).
- Expected: they swap back.
- Capture a screenshot after each reorder.

### Scenario 10: Saving a dashboard requires a name and at least one visualization

- On `http://localhost:4070/dashboards/new` with no visualizations, click "Save Dashboard".
- Expected: an error message appears containing "at least one visualization" — no redirect occurs.
- Select a template (e.g., Marketing Overview) to add visualizations. Clear the dashboard name field (submit with empty name via `phx-change`). Click "Save Dashboard".
- Expected: inline error on the name field showing "can't be blank" — no redirect occurs.
- Capture screenshots of both error states.

### Scenario 11: Naming and saving a new dashboard

- On `http://localhost:4070/dashboards/new`, select the "Marketing Overview" template (this populates visualizations).
- Fill in the "Dashboard Name" input with "QA Test Dashboard".
- Click "Save Dashboard".
- Expected: redirected to `/dashboards/<id>` (the saved dashboard show page) with a success flash "Dashboard created."
- Capture a screenshot of the post-save dashboard show page.

### Scenario 12: Saved dashboard appears in the dashboard list

- After saving in Scenario 11, navigate to `http://localhost:4070/dashboards`.
- Expected: "QA Test Dashboard" appears in the list.
- Capture a screenshot of the dashboard list showing the saved report.

### Scenario 13: Editing a saved dashboard

- From the dashboard list, navigate to the edit route `/dashboards/<id>/edit` for "QA Test Dashboard".
- Expected: editor loads with heading "Edit Dashboard"; the Dashboard Name field is pre-populated with "QA Test Dashboard".
- Update the name to "QA Test Dashboard Edited" and click "Save Dashboard" (ensure at least one visualization is present on the canvas).
- Expected: redirected back to `/dashboards/<id>` with flash "Dashboard updated."
- Capture a screenshot of the edit page and of the post-save page.

### Scenario 14: Cancel link returns to the dashboard list

- Navigate to `http://localhost:4070/dashboards/new` and click the "Cancel" link.
- Expected: navigated to `/dashboards`.
- Capture a screenshot.

## Result Path

`.code_my_spec/qa/443/result.md`
