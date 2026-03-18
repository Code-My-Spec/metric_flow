# MetricFlowWeb.VisualizationLive.Editor

Create or edit an individual standalone visualization. Authenticated users can select metrics, pick a chart type (line, bar, area), and preview a Vega-Lite chart built from real synced metric data queried from the Metrics context via the Dashboards context. The resulting visualization is saved with its Vega-Lite spec and query parameters, and may later be added to any dashboard via the Dashboard editor. Unauthenticated requests are redirected to `/users/log-in` by the router's `:require_authenticated_user` pipeline.

## Type

liveview

## Route

- `/visualizations/new` (`:new` live action)
- `/visualizations/:id/edit` (`:edit` live action)

## Params

- `id` (edit action only): integer ID of the visualization to edit. If not found or not owned by the current user, redirects to `/visualizations` with an error flash "Visualization not found."

## Dependencies

- MetricFlow.Dashboards

## Components

None

## User Interactions

- **phx-change="validate_name"** on the visualization name input: Validates the name field on each keystroke. Updates the changeset in assigns and displays an inline validation error when the name is blank or exceeds 255 characters.
- **phx-click="select_metric"** with `phx-value-metric={metric}`: Toggles a metric in the selected metrics list. When selected, adds the metric to `selected_metrics` MapSet in assigns and highlights the button. When deselected, removes it. Resets `chart_preview` to nil so the preview refreshes. At least one metric must be selected to preview or save.
- **phx-click="select_chart_type"** with `phx-value-chart_type={type}` (line, bar, area): Selects a chart type. Updates `selected_chart_type` in assigns and highlights the active chart type button. Resets `chart_preview` to nil.
- **phx-click="preview_chart"** (`data-role="preview-chart-btn"`): Queries real synced metric data by calling `Dashboards.get_dashboard_data/2` with the scope and default date range, filters time_series to only the selected metrics, then builds the Vega-Lite spec using the appropriate ChartBuilder function based on chart_type (line uses `build_time_series_spec/2` for single metric or `build_multi_series_spec/2` for multiple metrics, bar uses `build_bar_chart_spec/2`, area uses `build_area_chart_spec/2`). Assigns the resulting spec to `chart_preview`. Disabled when no metrics are selected.
- **phx-click="toggle_shareable"** (`data-role="toggle-shareable"`): Toggles the `shareable` boolean in assigns between true and false.
- **phx-click="save_visualization"** (`data-role="save-visualization-btn"`): Validates the current name and selected metrics. If name is blank or no metrics selected, assigns field-level errors without persisting. Otherwise, builds the final Vega-Lite spec from real data (same as preview), then calls `Dashboards.save_visualization/2` (new action) or `Dashboards.update_visualization/3` (edit action) with `%{name: name, metric_name: Enum.join(selected_metrics, ","), chart_type: selected_chart_type, shareable: shareable, vega_spec: chart_preview}`. On `{:ok, visualization}`, navigates to `/visualizations` with a success flash "Visualization saved." On `{:error, changeset}`, assigns the changeset errors and re-renders without redirecting.

## Design

Layout: Full-width page within the `Layouts.app` shell, content constrained to `max-w-3xl mx-auto` with horizontal padding `px-4 py-8`.

### Page header

Flex row, `flex items-center justify-between flex-wrap gap-3`.
- Left: H1 "New Visualization" or "Edit Visualization" (bold).
- Right: `.btn.btn-primary.btn-sm` "Save Visualization" (`data-role="save-visualization-btn"`) and a `.btn.btn-ghost.btn-sm` link "Cancel" navigating back to `/visualizations`.

### Name field

`.form-control` wrapper, label "Visualization Name", text input (`data-role="visualization-name-input"`, `phx-change="validate_name"`, placeholder "My Visualization"). Shows `input-error` class and inline error text when name validation fails.

### Metric selector (`data-role="metric-selector"`)

`.mf-card p-5 mb-4`.
- Section label "Choose Metrics" in `font-semibold text-sm`. Helper text "(select one or more)" in muted.
- Scrollable flex-wrap row (`data-role="metric-list"`) of `.btn.btn-sm` buttons, one per available metric. Selected metrics use `.btn-primary`; others use `.btn-ghost`. Multiple selection supported.
- Empty state (`data-role="no-metrics-available"`): muted text "No metrics available. Connect a platform to get started." with a `.btn.btn-ghost.btn-sm` link to `/integrations`.

### Chart type selector (`data-role="chart-type-selector"`)

`.mf-card p-5 mb-4`.
- Section label "Chart Type" in `font-semibold text-sm`.
- Three `.btn.btn-sm` buttons side by side: "Line", "Bar", "Area". Active type uses `.btn-primary`; others use `.btn-ghost`.

### Options row

Flex row, `flex items-center gap-4 mb-4`.
- Shareable toggle (`data-role="toggle-shareable"`): `.btn.btn-sm` labelled "Shareable" (uses `.btn-primary` when shareable is true, `.btn-ghost` when false). Tooltip or muted helper text: "Let others add this visualization to their dashboards."

### Chart preview (`data-role="chart-preview-section"`)

`.mf-card p-5 mb-4`.
- Section header flex row: label "Preview" in `font-semibold text-sm`, `.btn.btn-outline.btn-sm` "Preview Chart" (`data-role="preview-chart-btn"`, `phx-click="preview_chart"`) on the right. Button is disabled and shows `.btn-disabled` when no metrics are selected.
- Preview area: When `chart_preview` is nil, shows a centered placeholder (`data-role="chart-placeholder"`) with muted text "Select metrics and click Preview Chart to see your data." When `chart_preview` is set, renders the Vega-Lite chart container (`data-role="vega-lite-chart"`, `phx-hook="VegaLite"`) with `data-spec={Jason.encode!(chart_preview)}`.

Components: `.mf-card`, `.btn`, `.btn-primary`, `.btn-ghost`, `.btn-outline`, `.btn-sm`, `.btn-disabled`, `.form-control`, `.label`, `.input`, `.input-error`

Responsive: All cards stack vertically. Header row wraps on mobile. Metric list wraps into multiple rows on narrow viewports.
