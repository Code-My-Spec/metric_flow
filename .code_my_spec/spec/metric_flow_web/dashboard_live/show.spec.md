# MetricFlowWeb.DashboardLive.Show

View a dashboard with its visualizations. For the default "All Metrics" canned dashboard, renders a single multi-series Vega-Lite line chart (all metrics as colored lines on one chart) plus an HTML data table (rows = months, columns = metric names, cells = values) with date range picker, platform filter, and metric toggles. For custom user dashboards, renders arranged visualizations from the dashboard's visualization collection. When no integrations are connected, renders an onboarding prompt. Unauthenticated users are redirected to `/users/log-in` by the router's authentication plug.

## Type

liveview

## Route

- `/dashboard` — default "All Metrics" canned dashboard
- `/dashboards/:id` — view a specific user or canned dashboard

## Params

- `id` (optional): integer ID of the dashboard to view. When omitted, loads the default "All Metrics" canned dashboard. If not found or not accessible, redirects to `/dashboards` with an error flash.

## Dependencies

- MetricFlow.Dashboards

## Components

None

## User Interactions

- **phx-click="filter_platform"** with `phx-value-platform="all"`: Clears the platform filter, calls `Dashboards.get_dashboard_data/2` with no platform constraint, rebuilds the multi-series chart spec, and re-renders.
- **phx-click="filter_platform"** with `phx-value-platform={platform}`: Filters metrics to the selected platform, calls `Dashboards.get_dashboard_data/2` with the platform option, rebuilds chart spec, highlights active filter button.
- **phx-click="filter_date_range"** with `phx-value-range={range_key}`: Changes the active date window (last_7_days, last_30_days, last_90_days, all_time, custom), calls `Dashboards.get_dashboard_data/2` with the resolved date range tuple, rebuilds chart spec and data table.
- **phx-click="toggle_metric"** with `phx-value-metric={metric_name}`: Toggles visibility of the named metric in the multi-series chart and data table. When toggled off, the metric is excluded from the chart spec rebuild and hidden in the table. Toggled state is tracked in assigns as a MapSet of visible metric names. All metrics are visible by default.
- **phx-click="show_ai_insights"** with `phx-value-metric={metric_name}`: Opens the inline AI insights panel scoped to the named metric.
- **phx-click="hide_ai_insights"**: Closes the AI insights panel.
- **phx-click="open_ai_chat"**: Opens the inline AI chat panel.
- **phx-click="close_ai_chat"**: Closes the inline AI chat panel.

## Design

Layout: Full-width page within the `Layouts.app` shell, content constrained to `max-w-6xl mx-auto` with horizontal padding.

Header row:
- Left: Page title "All Metrics" (h1, bold) with subtitle "Your complete marketing and financial picture" (muted). For custom dashboards, title is the dashboard name.
- Right: Ghost button "AI Chat" (`data-role="open-ai-chat"`) that toggles the inline chat panel.

Inline AI chat panel (shown when `chat_panel_open` is true):
- `.mf-card p-5 mb-6` container, `data-role="ai-chat-interface"`.
- Header with title "AI Chat" and close button (`data-role="close-chat-panel"`).
- Brief description text.
- Primary link button navigating to `/chat` ("Open Full AI Chat").

Onboarding prompt (shown when `has_integrations` is false):
- `.mf-card p-8 text-center` container, `data-role="onboarding-prompt"`.
- Heading "Connect Your Platforms", descriptive paragraph, primary button linking to `/integrations`.

Metrics dashboard (shown when `has_integrations` is true), `data-role="metrics-dashboard"`:

  Filter controls row (`flex items-center gap-4 flex-wrap`):
  - Platform filter (`data-role="platform-filter"`): "All Platforms" button plus one button per connected platform; active button uses `.btn-primary`, inactive uses `.btn-ghost`.
  - Date range filter (`data-role="date-range-filter"`): Buttons for last_7_days, last_30_days, last_90_days, all_time, custom; active button uses `.btn-primary`.

  Date range label (`data-role="date-range"`): Small muted text showing the applied date window.

  Metric toggles (`data-role="metric-toggles"`):
  - Scrollable flex-wrap row of `.btn.btn-xs` toggle buttons, one per available metric name. Active (visible) metrics use `.btn-primary`; hidden metrics use `.btn-ghost`. Each button triggers `toggle_metric` with the metric name.

  Multi-series chart (`data-role="multi-series-chart"`):
  - `.mf-card p-4` container.
  - Section header "Metrics Over Time" in `font-semibold`.
  - Vega-Lite chart container (`data-role="vega-lite-chart"`, `phx-hook="VegaLite"`) receives the multi-series spec via `data-spec`. The spec is built by calling `Dashboards.build_multi_series_chart_spec/2` with the title and the filtered/toggled time_series data from `get_dashboard_data`.
  - Empty-state: muted text "No metric data available for the selected filters." when time_series is empty.

  Data table (`data-role="data-table"`):
  - `.mf-card p-4 mt-4 overflow-x-auto` container.
  - Section header "Monthly Data" in `font-semibold`.
  - HTML `<table>` with `.table.table-sm.table-zebra` classes.
  - `<thead>`: First column "Month", then one column per visible metric name.
  - `<tbody>`: One row per month (grouped from time_series data). Each cell shows the metric value for that month, formatted as a number. Months are sorted chronologically (oldest first).
  - Empty-state: muted text "No data to display." when no metrics are visible or no data exists.

  Summary stats grid (`data-role="summary-stats"`, `grid grid-cols-2 sm:grid-cols-4 gap-4 mt-4`):
  - Each card (`data-role="stat-card"`, `.mf-card p-4`) shows metric name, sum in JetBrains Mono (`.mf-metric`), and average. Only shows stats for visible (toggled-on) metrics.
  - Empty-state fallback card when no stats match.

  AI insights panel (shown when `ai_panel_open` is true):
  - `.mf-card p-5 mt-4`, `data-role="ai-insights-panel"`. Shows metric name in header, close button, brief insight, link to `/insights`.

Components: `.mf-card`, `.btn`, `.btn-primary`, `.btn-ghost`, `.btn-sm`, `.btn-xs`, `.table`, `.table-sm`, `.table-zebra`, `.badge`, `.link`, `.link-primary`.
Responsive: Stats grid collapses to 2 columns on mobile. Data table scrolls horizontally. Filter rows and metric toggles wrap on small viewports.

## Test Assertions

- renders dashboard page with All Metrics title for default route
- shows onboarding prompt when no integrations are connected
- displays metrics dashboard with chart and data table when integrations exist
- filters metrics by platform when platform filter button is clicked
- changes date range when date range filter button is clicked
- toggles metric visibility when metric toggle button is clicked
- highlights active platform and date range filter buttons with btn-primary
- shows AI chat panel when AI Chat button is clicked and hides on close
- shows AI insights panel for a metric and hides on close
- shows empty state in chart and table when no data matches filters
- displays summary stats grid with metric sums and averages
- renders custom dashboard by ID with dashboard name as title
