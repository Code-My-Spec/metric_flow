# MetricFlowWeb.ReportLive.Show

View a single report with its visualizations and metric summaries. Renders report content including review metrics, rolling averages, and cross-platform comparisons in a read-only presentable format. Supports sharing and export actions.

## Type

liveview

## Route

`/reports/:id`

## Params

- `id` - integer, the report ID

## Dependencies

- MetricFlow.Dashboards
- MetricFlow.Metrics

## Components

None

## User Interactions

- **mount**: Loads the report by ID via `Dashboards.get_visualization/2`. If not found, redirects to `/reports` with error flash. Assigns report data and metric summaries.
- **phx-click=share**: Copies a shareable URL to clipboard and shows info flash.

## Design

Layout: Centered single-column page, `max-w-5xl mx-auto`, `.mf-content` wrapper.

Header: Report name as H1, Back to Reports link, Share button.

Report content: Vega-Lite chart rendered via VegaLite hook, metric summary cards below.

Components: `.mf-card`, `.btn`, `.btn-primary`, `.btn-ghost`, `.btn-sm`

Responsive: Single column on all viewports.
