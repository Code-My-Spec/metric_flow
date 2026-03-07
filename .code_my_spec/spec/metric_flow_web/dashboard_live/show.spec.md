# MetricFlowWeb.DashboardLive.Show

View dashboard with visualizations. Displays unified marketing and financial metrics from all connected platforms via Vega-Lite time series charts, summary stat cards, and filter controls. When no integrations are connected, renders an onboarding prompt. Unauthenticated users are redirected to `/users/log-in` by the router's authentication plug.

## Type

liveview

## Route

`/dashboard`

## Params

None

## Dependencies

- MetricFlow.Dashboards

## Components

None

## User Interactions

- **phx-click="filter_platform"** with `phx-value-platform="all"`: Clears the platform filter, calls `Dashboards.get_dashboard_data/2` with no platform constraint, and re-renders the metrics area.
- **phx-click="filter_platform"** with `phx-value-platform={platform}`: Filters all stats and charts to the selected platform, calls `Dashboards.get_dashboard_data/2` with the platform option, and highlights the active filter button.
- **phx-click="filter_date_range"** with `phx-value-range={range_key}`: Changes the active date window (last_7_days, last_30_days, last_90_days, all_time, custom), calls `Dashboards.get_dashboard_data/2` with the resolved date range tuple, and updates the displayed date range label.
- **phx-click="filter_metric_type"** with `phx-value-metric_type="all"`: Clears the metric type filter, calls `Dashboards.get_dashboard_data/2` with no type constraint.
- **phx-click="filter_metric_type"** with `phx-value-metric_type={type}`: Filters to a specific metric type (e.g., "traffic"), calls `Dashboards.get_dashboard_data/2` with the type option.
- **phx-click="show_ai_insights"** with `phx-value-metric={metric_name}`: Opens the inline AI insights panel scoped to the named metric, setting `ai_panel_open` to true and `ai_panel_metric` to the metric name.
- **phx-click="hide_ai_insights"**: Closes the AI insights panel by setting `ai_panel_open` to false.
- **phx-click="open_ai_chat"**: Opens the inline AI chat panel by setting `chat_panel_open` to true.
- **phx-click="close_ai_chat"**: Closes the inline AI chat panel by setting `chat_panel_open` to false.

## Design

Layout: Full-width page within the `Layouts.app` shell, content constrained to `max-w-5xl mx-auto` with horizontal padding.

Header row:
- Left: Page title "All Metrics" (h1, bold) with subtitle "Your complete marketing and financial picture" (muted).
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
  - Metric type filter (`data-role="metric-type-filter"`): "All Types" button plus one button per available metric type.

  Date range label (`data-role="date-range"`): Small muted text showing the applied date window with a note that today is excluded.

  Metrics area (`data-role="metrics-area"`):
  - Summary stats grid: `grid grid-cols-2 sm:grid-cols-4 gap-4`. Each card (`data-role="stat-card"`, `.mf-card p-4`) shows metric name, sum in JetBrains Mono (`.mf-metric`, `data-role="stat-sum"`), and average (`data-role="stat-avg"`). Empty-state fallback card shown when no stats match filters.
  - Charts section (`data-role="metrics-data"`, `data-chart-type="vega-lite"`): One card per time series entry (`data-role="chart-card"`, `.mf-card p-4`). Each card has a header with the metric name and an "AI Info" ghost button (`data-role="ai-info-button"`) that triggers `show_ai_insights`. The Vega-Lite chart container (`data-role="vega-lite-chart"`, `phx-hook="VegaLite"`) receives the chart spec via `data-spec`. Empty-state fallback shown when no time series data matches filters.
  - AI insights panel (shown when `ai_panel_open` is true): `.mf-card p-5 mt-4`, `data-role="ai-insights-panel"`. Shows metric name in header, close button (`data-role="close-button"`), brief insight description, and a link to `/insights`.
  - Platform-specific metrics section (`data-role="platform-specific-metrics-section"`): Grid of stat cards for non-canonical metrics. Each card (`data-role="platform-specific-metric"`) shows metric name, a "Platform-Specific" badge, sum, and provider attribution. When empty, shows a text note that all synced metrics map to the canonical taxonomy.
  - Semantic warning footnote (`data-role="semantic-warning"`, `data-semantic-difference="attribution"`): Explains cross-platform attribution window differences.

Components: `.mf-card`, `.btn`, `.btn-primary`, `.btn-ghost`, `.btn-sm`, `.btn-xs`, `.badge`, `.badge-ghost`, `.link`, `.link-primary`.
Responsive: Summary stat grid collapses to 2 columns on mobile (`grid-cols-2`), expanding to 4 on sm+. Filter rows wrap on small viewports.
