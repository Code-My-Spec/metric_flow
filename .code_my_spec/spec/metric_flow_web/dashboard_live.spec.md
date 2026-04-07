# MetricFlowWeb.DashboardLive

Dashboard management UI views.

## Type

live_context

## LiveViews

### DashboardLive.Show

- **Route:** `/dashboard` and `/dashboards/:id`
- **Description:** Displays a dashboard with Vega-Lite visualizations. The default route shows the "All Metrics" multi-series line chart with data table, granularity controls, date range picker, platform filter, and per-metric toggles. Shows onboarding prompt when no integrations are connected.

### DashboardLive.Index

- **Route:** `/dashboards`
- **Description:** Lists dashboards available to the authenticated user, including saved and system-provided canned dashboards. Supports inline delete confirmation for user-owned dashboards.

### DashboardLive.Editor

- **Route:** `/dashboards/new` and `/dashboards/:id/edit`
- **Description:** Creates and edits custom dashboards. Allows composing visualizations from connected platform metrics into a named layout. Supports creating from blank canvas or canned template.

## Components

None — each LiveView is self-contained.

## Dependencies

- MetricFlow.Dashboards
