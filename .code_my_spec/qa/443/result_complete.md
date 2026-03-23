# QA Result

## Status

pass

## Scenarios

### Scenario 1: Unauthenticated access is blocked

pass

Navigated to `http://localhost:4070/dashboards/new` without a session. The browser was immediately redirected to `/users/log-in`. The editor page was not shown to the unauthenticated visitor.

Evidence: `screenshots/01-unauthenticated-redirect.png`

### Scenario 2: New Dashboard editor page loads for authenticated user

pass

After logging in as `qa@example.com`, navigated to `/dashboards/new`. The page loaded with:
- H1 heading "New Dashboard"
- `[data-role="dashboard-name-input"]` input with placeholder "My Dashboard"
- `[data-role="save-dashboard-btn"]` button with label "Save Dashboard"
- A `Cancel` link (`<a href="/dashboards" class="btn btn-ghost">`) pointing to `/dashboards`

Evidence: `screenshots/02-new-dashboard-editor.png`

### Scenario 3: Template chooser is shown on the blank new-dashboard page

pass

On `/dashboards/new` with no visualizations, `[data-role="template-chooser"]` was visible. It contained the introductory text "Start from a template or blank canvas", template cards for "Marketing Overview" (`data-role="template-card-marketing_overview"`) and "Financial Summary" (`data-role="template-card-financial_summary"`), and a "Blank Canvas" card (`data-role="template-card-blank"`).

Evidence: `screenshots/03-template-chooser.png`

### Scenario 4: Selecting a template populates the canvas

pass

Clicked the "Marketing Overview" template card. Four visualization cards (`data-role="visualization-card"`) appeared on the canvas with metrics Clicks (bar), Spend (line), Impressions (area), and ROAS (line). The empty canvas state (`data-role="empty-canvas"`) disappeared and the template chooser (`data-role="template-chooser"`) was hidden (canvas is no longer empty).

Evidence: `screenshots/04-template-populated-canvas.png`

### Scenario 5: "+ Add Visualization" button opens the metric picker

pass

Clicked `[data-role="add-visualization-btn"]`. The metric picker panel (`data-role="metric-picker"`) appeared with:
- Title "Add Visualization"
- `[data-role="metric-list"]` containing metric buttons (metrics were present — e.g., `sessions`, `activeUsers`)
- `[data-role="chart-type-selector"]` with Line, Bar, Area buttons
- `[data-role="confirm-add-btn"]` button that was disabled (no metric selected)

Evidence: `screenshots/05-metric-picker-open.png`

### Scenario 6: Closing the metric picker without adding a visualization

pass

With the metric picker open, clicked `[data-role="close-metric-picker"]`. The metric picker panel became hidden immediately. Canvas state (4 visualization cards from template) remained unchanged.

Evidence: `screenshots/06-metric-picker-closed.png`

### Scenario 7: Adding a visualization manually via the metric picker

pass

Clicked "+ Add Visualization", then clicked the "sessions" metric button. The "sessions" button gained `btn-primary` class and the "Add to Dashboard" confirm button became enabled. Clicked the "Bar" chart type button — it gained `btn-primary` styling. Clicked "Add to Dashboard". The picker closed and a new visualization card appeared showing "sessions" with a "bar" badge. The total canvas card count increased from 4 to 5.

Evidence: `screenshots/07-visualization-added.png`

### Scenario 8: Removing a visualization from the canvas

pass

Started fresh on `/dashboards/new`, added a single "sessions" (line) visualization via the metric picker. Clicked the "Remove" (aria-label="Remove") button on the only visualization card. The card disappeared and the empty canvas state (`data-role="empty-canvas"`) reappeared with the text "Add a visualization to get started".

Evidence: `screenshots/08-after-removal-empty-canvas.png`

### Scenario 9: Reordering visualizations (move up / move down)

pass

Selected the "Marketing Overview" template (4 cards: Clicks, Spend, Impressions, ROAS). Clicked "Move down" on the first card ("Clicks"). The order became Spend, Clicks, Impressions, ROAS — confirming the swap. Then clicked "Move up" on the second card (now "Clicks"). The order returned to Clicks, Spend, Impressions, ROAS — confirming the reverse swap.

Evidence: `screenshots/09a-after-move-down.png`, `screenshots/09b-after-move-up.png`

### Scenario 10: Saving a dashboard requires a name and at least one visualization

pass

**Sub-scenario A — no visualizations:** Navigated to `/dashboards/new` and clicked "Save Dashboard" with an empty canvas. The error message "Please add at least one visualization to save the dashboard." appeared. URL remained `/dashboards/new`.

**Sub-scenario B — blank name:** Selected the "Marketing Overview" template. Filled the name field with a space character and pressed Tab to trigger `phx-change="validate_name"`. Clicked "Save Dashboard". The inline error "can't be blank" appeared under the name field. URL remained `/dashboards/new`.

Evidence: `screenshots/10a-error-no-visualizations.png`, `screenshots/10b-error-blank-name.png`

### Scenario 11: Naming and saving a new dashboard

pass

Navigated to `/dashboards/new`, selected "Marketing Overview" template, filled the name field with "QA Test Dashboard", and clicked "Save Dashboard". Redirected to `http://localhost:4070/dashboards/7` with success flash "Dashboard created."

Evidence: `screenshots/11-post-save-dashboard-show.png`

### Scenario 12: Saved dashboard appears in the dashboard list

pass

Navigated to `/dashboards`. "QA Test Dashboard" appeared in the "My Dashboards" section of the list. (Additional dashboards from prior test runs were also visible — these are expected leftover test data.)

Evidence: `screenshots/12-dashboard-list.png`

### Scenario 13: Editing a saved dashboard

pass

Navigated to `/dashboards/7/edit`. Page loaded with H1 "Edit Dashboard" and the name field pre-populated with "QA Test Dashboard". Updated the name to "QA Test Dashboard Edited" and clicked "Save Dashboard". Redirected to `/dashboards/7` with flash "Dashboard updated."

Evidence: `screenshots/13a-edit-dashboard-page.png`, `screenshots/13b-after-edit-save.png`

### Scenario 14: Cancel link returns to the dashboard list

pass

Navigated to `/dashboards/new` and clicked the "Cancel" link. Navigated to `/dashboards` as expected.

Evidence: `screenshots/14-cancel-link-destination.png`

## Evidence

- `screenshots/01-unauthenticated-redirect.png` — login page after redirect from `/dashboards/new` without session
- `screenshots/02-new-dashboard-editor.png` — initial state of the New Dashboard editor page
- `screenshots/03-template-chooser.png` — template chooser visible on blank canvas
- `screenshots/04-template-populated-canvas.png` — canvas populated after selecting Marketing Overview template
- `screenshots/05-metric-picker-open.png` — metric picker open with metrics list and chart type selector
- `screenshots/06-metric-picker-closed.png` — metric picker dismissed, canvas unchanged
- `screenshots/07-visualization-added.png` — sessions/bar visualization card added via picker
- `screenshots/08-after-removal-empty-canvas.png` — empty canvas state after removing the last visualization
- `screenshots/09a-after-move-down.png` — canvas order after moving first card down (Spend first)
- `screenshots/09b-after-move-up.png` — canvas order restored after moving card back up (Clicks first)
- `screenshots/10a-error-no-visualizations.png` — viz_error shown when saving with empty canvas
- `screenshots/10b-error-blank-name.png` — inline name error shown when name is blank
- `screenshots/11-post-save-dashboard-show.png` — post-save dashboard show page with "Dashboard created." flash
- `screenshots/12-dashboard-list.png` — dashboard list showing "QA Test Dashboard"
- `screenshots/13a-edit-dashboard-page.png` — edit page with "Edit Dashboard" heading and pre-filled name
- `screenshots/13b-after-edit-save.png` — post-edit show page with "Dashboard updated." flash
- `screenshots/14-cancel-link-destination.png` — /dashboards list after Cancel link click

## Issues

None
