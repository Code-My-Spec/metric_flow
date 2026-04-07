# MetricFlowWeb.VisualizationLive

Data visualization UI views.

## Type

live_context

## LiveViews

### VisualizationLive.Index

- **Route:** `/visualizations`
- **Description:** Lists saved standalone visualizations for the authenticated user. Supports inline delete confirmation.

### VisualizationLive.Editor

- **Route:** `/visualizations/new` and `/visualizations/:id/edit`
- **Description:** Creates and edits standalone Vega-Lite chart visualizations from available metrics. Supports preview and save to the user's visualization library.

## Components

None — each LiveView is self-contained.

## Dependencies

- MetricFlow.Dashboards
