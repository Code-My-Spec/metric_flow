# MetricFlowWeb.ReportLive

Report viewing and generation UI views.

## Type

live_context

## LiveViews

### ReportLive.Index

- **Route:** `/reports` and `/reports/new`
- **Description:** Lists saved reports for the authenticated user. Displays user-created and system-generated reports including review summaries, rolling averages, and cross-platform snapshots. The `:new` action provides a new-report flow from templates or blank canvas.

### ReportLive.Show

- **Route:** `/reports/:id`
- **Description:** Views a single report with its Vega-Lite chart, metric summary cards, and cross-platform comparisons in a read-only presentable format. Supports sharing via copyable URL.

## Components

None — each LiveView is self-contained.

## Dependencies

- MetricFlow.Dashboards
- MetricFlow.Metrics
