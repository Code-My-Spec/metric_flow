# MetricFlowWeb.DashboardLive.Editor

Create/edit dashboards, arrange visualizations.

Allows authenticated users to build reports by composing visualizations from connected platform metrics, placing them into a named layout, and saving the result. Supports creating a new dashboard from a blank canvas or a canned template, and editing an existing saved dashboard. Unauthenticated requests are redirected to `/users/log-in` by the router's `:require_authenticated_user` pipeline.

## Type

liveview

## Route

- `/dashboards/new` (`:new` live action)
- `/dashboards/:id/edit` (`:edit` live action)

## Params

- `id` (edit action only): integer ID of the dashboard to edit. If not found, redirects to `/dashboard` with an error flash.

## Dependencies

- MetricFlow.Dashboards

## Components

None

## User Interactions

- **phx-change="validate_name"** on the dashboard name input: Validates the name field on each keystroke. Updates the changeset and displays an inline error message if the name is blank.
- **phx-click="save_dashboard"** (`data-role="save-dashboard-btn"`): Saves the dashboard. If no visualizations have been added, assigns a `viz_error` message. Otherwise calls `Dashboards.save_dashboard/2` (new) or `Dashboards.update_dashboard/3` (edit) with the current name and navigates to the saved dashboard show page on success.
- **phx-click="select_template"** with `phx-value-template={key}` (`data-role="template-card-{key}"`): Shown only on the `:new` route when the canvas is empty. Applies the named template's predefined visualizations to the canvas and marks the template as selected (ring highlight).
- **phx-click="clear_canvas"** with `phx-confirm` (`data-role="template-card-blank"`): Clears all visualizations from the canvas and selects the "blank" template.
- **phx-click="open_metric_picker"** (`data-role="add-visualization-btn"`): Opens the metric picker panel, resetting the selected metric and chart type.
- **phx-click="close_metric_picker"** (`data-role="close-metric-picker"`): Closes the metric picker panel without adding a visualization.
- **phx-click="select_metric"** with `phx-value-metric={metric}`: Selects a metric within the metric picker. Highlights the selected metric button.
- **phx-click="select_chart_type"** with `phx-value-chart_type={type}`: Selects a chart type (line, bar, area) within the metric picker. Highlights the active chart type button.
- **phx-click="add_visualization"** (`data-role="confirm-add-btn"`): Adds the currently selected metric and chart type as a new visualization card to the canvas. Disabled when no metric is selected. Closes the picker on success.
- **phx-click="remove_visualization"** with `phx-value-index={idx}` (aria-label "Remove"): Removes the visualization at the given index from the canvas and renumbers remaining positions.
- **phx-click="move_visualization_up"** with `phx-value-index={idx}` (aria-label "Move up"): Swaps the visualization at index with the one above it.
- **phx-click="move_visualization_down"** with `phx-value-index={idx}` (aria-label "Move down"): Swaps the visualization at index with the one below it.

## Design

Layout: Full-width page within the `Layouts.app` shell, content constrained to `max-w-5xl mx-auto` with horizontal padding.

Header row:
- Left: Page title "New Dashboard" or "Edit Dashboard" (h1, bold).
- Right: Primary button "Save Dashboard" (`data-role="save-dashboard-btn"`) and a ghost link "Cancel" navigating back to `/dashboard`.

Dashboard name field:
- Text input (`data-role="dashboard-name-input"`, `phx-change="validate_name"`) with label "Dashboard Name" and placeholder "My Dashboard". Shows `input-error` class and inline error text when the name validation fails.

Visualization count error:
- Small error text paragraph shown when `viz_error` is assigned (e.g., "Please add at least one visualization to save the dashboard.").

Template chooser (`data-role="template-chooser"`, shown only on `:new` when canvas is empty):
- Introductory muted text "Start from a template or blank canvas".
- Grid (`grid grid-cols-2 sm:grid-cols-4 gap-4`) of template cards: one card per built-in template (`data-role="template-card-{key}"`) showing the template label and description, plus a "Blank Canvas" card (`data-role="template-card-blank"`). Selected template card has `ring-2 ring-primary` highlight.

Add Visualization button:
- Outline small button (`data-role="add-visualization-btn"`, `phx-click="open_metric_picker"`) labelled "+ Add Visualization".

Metric picker panel (`data-role="metric-picker"`, `.mf-card p-5 mb-6`, shown when `picker_open` is true):
- Header with title "Add Visualization" and close button (`data-role="close-metric-picker"`).
- Metric list (`data-role="metric-list"`): Scrollable flex-wrap row of buttons, one per available metric. Selected metric button uses `.btn-primary`; others use `.btn-ghost`. Empty state shows muted text "No metrics available. Connect a platform to get started."
- Chart type selector (`data-role="chart-type-selector"`): Three buttons for "Line", "Bar", "Area". Active type uses `.btn-primary`.
- Confirm button (`data-role="confirm-add-btn"`, `phx-click="add_visualization"`): "Add to Dashboard", disabled when no metric is selected.

Visualization canvas (`data-role="visualization-canvas"`, `space-y-4 mb-6`):
- Empty state (`data-role="empty-canvas"`): Centred card with muted text "Add a visualization to get started", shown when no visualizations exist.
- Visualization cards (`data-role="visualization-card"`, `.mf-card p-4`): One per visualization in the list. Each card shows the metric name, a badge with the chart type, up/down reorder buttons (aria-labels "Move up" / "Move down"), a remove button (aria-label "Remove", `.btn-error`), and a chart preview placeholder (`data-role="chart-preview"`).

Components: `.mf-card`, `.btn`, `.btn-primary`, `.btn-ghost`, `.btn-outline`, `.btn-sm`, `.btn-xs`, `.btn-error`, `.badge`, `.badge-ghost`, `.badge-sm`, `.input`, `.input-error`, `.form-control`, `.label`.
Responsive: Template chooser grid collapses to 2 columns on mobile, expanding to 4 on sm+. Header row uses flex layout that wraps on small viewports.
