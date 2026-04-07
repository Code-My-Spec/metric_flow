# Design Review

## Overview

Reviewed MetricFlowWeb.VisualizationLive context with 2 child LiveViews: Index and Editor. The architecture is sound after fixing a type mismatch on the Index spec. Clean CRUD pattern for standalone visualizations.

## Architecture

- Clear separation: Index lists visualizations with delete support, Editor handles create/edit with metric selection, chart type, and Vega-Lite preview
- Both views depend solely on MetricFlow.Dashboards — single context dependency
- Editor supports `:new` and `:edit` live actions with shared UI — standard Phoenix pattern
- Vega-Lite chart rendering uses `phx-hook="VegaLite"` with `data-spec` attribute for CSP-safe rendering

## Integration

- Index links to Editor (`/visualizations/new`) for creation and (`/visualizations/:id/edit`) for editing
- Editor redirects to Index (`/visualizations`) after successful save
- Editor links to `/integrations` in empty metric state to guide users to connect data sources
- Visualizations created here can be added to dashboards via the DashboardLive.Editor
- Both views use router-level auth plugs and scope data via `current_scope`

## Issues

- **Index spec had type `module` instead of `liveview`**: It has mount/handle_event/render callbacks and a route — it is a LiveView. Changed type to `liveview` and added Route section.

## Conclusion

The VisualizationLive context is ready for implementation. All dependencies are verified, the type mismatch has been fixed, and specs are consistent.
