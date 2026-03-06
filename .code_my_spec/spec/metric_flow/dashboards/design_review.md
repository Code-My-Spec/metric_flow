# Design Review

## Overview

Reviewed MetricFlow.Dashboards context and its 6 child components: ChartBuilder, Dashboard, DashboardVisualization, Visualization, DashboardsRepository, and VisualizationsRepository. The architecture is sound for its current scope — the context provides a clean read-only API for the Story 441 "All Metrics" dashboard and the schema layer is complete and consistent. No spec-level issues required fixes; one coherence observation about unused ChartBuilder functions is noted below.

## Architecture

- **Separation of concerns is well-defined**: ChartBuilder handles pure Vega-Lite spec construction with no side effects. Dashboard, Visualization, and DashboardVisualization handle schema validation via changesets. DashboardsRepository and VisualizationsRepository are intentionally empty stubs pending dashboard editor stories. The context orchestrates data assembly from Metrics and Integrations.
- **Context scope is appropriate for Story 441**: The five public functions (`get_dashboard_data/2`, `build_chart_spec/2`, `default_date_range/0`, `available_date_ranges/0`, `has_integrations?/1`) are a coherent, minimal API for the "All Metrics" read-only dashboard view.
- **Scope pattern is correctly applied**: All public context functions that require user identity accept `Scope.t()` as the first parameter (`get_dashboard_data/2`, `has_integrations?/1`). Pure functions (`build_chart_spec/2`, `default_date_range/0`, `available_date_ranges/0`) correctly omit Scope.
- **Delegation is correct and verifiable**: The single delegate `build_chart_spec/2` -> `ChartBuilder.build_time_series_spec/2` matches the ChartBuilder spec exactly — same arity, same parameter types, same return type.
- **Dependencies are valid**: `MetricFlow.Metrics` and `MetricFlow.Integrations` both exist in the architecture and expose the exact functions the context calls (`list_integrations/1`, `list_metric_names/2`, `query_time_series/3`, `aggregate_metrics/3`). All call sites in the `get_dashboard_data/2` process match the Metrics and Integrations context signatures.
- **ChartBuilder has two functions not called by the current context**: `build_bar_chart_spec/2` and `build_summary_card_spec/2` are specified in ChartBuilder but are not delegated or called by the context in its current form. `get_dashboard_data/2` returns raw `aggregate_metrics/3` maps as `summary_stats` rather than calling `build_summary_card_spec/2`. This is not a bug — the LiveView can call `build_chart_spec/2` per metric and render summary stats directly — but the design intent for these functions should be confirmed when the dashboard editor stories arrive.
- **Repository stubs intentionally empty**: DashboardsRepository and VisualizationsRepository contain no functions. This is by design — Story 441 does not persist custom dashboards. The stubs exist to establish the module boundaries for future editor stories.
- **Schema layer is complete**: Dashboard, Visualization, and DashboardVisualization each have well-formed `changeset/2` functions with appropriate validations. Dashboard and Visualization have sensible helper predicates (`built_in?/1`, `shareable?/1`). The DashboardVisualization junction schema enforces the unique constraint on `{dashboard_id, visualization_id}` correctly.

## Integration

- **Context -> Metrics**: `get_dashboard_data/2` calls `Metrics.list_metric_names/2` to discover distinct metric names, then calls `Metrics.query_time_series/3` and `Metrics.aggregate_metrics/3` per metric name to build the `time_series` and `summary_stats` lists. Filters (platform, date_range, metric_type) pass through to Metrics with platform mapped to the provider option.
- **Context -> Integrations**: `get_dashboard_data/2` calls `Integrations.list_integrations/1` to populate `connected_platforms` and derive `available_filters.platforms`. `has_integrations?/1` delegates the same call and checks for a non-empty list.
- **Context -> ChartBuilder**: `build_chart_spec/2` delegates directly to `ChartBuilder.build_time_series_spec/2`. No other ChartBuilder functions are wired to the context at this time.
- **Schemas -> future Repositories**: Dashboard, Visualization, and DashboardVisualization `changeset/2` functions will be consumed by DashboardsRepository and VisualizationsRepository once CRUD operations are added in editor stories.
- **Context -> LiveView**: `get_dashboard_data/2` returns a fully assembled map with `time_series`, `summary_stats`, `available_filters`, `connected_platforms`, and `applied_filters`. The LiveView can pass individual `time_series` entries directly to `build_chart_spec/2` for Vega-Lite rendering without additional transformation.

## Stories

- **Story 441 "View All Metrics Dashboard"** is the driving story for the current context spec. Coverage is complete: `has_integrations?/1` controls the onboarding gate, `get_dashboard_data/2` supplies all dashboard data, `build_chart_spec/2` produces chart specs for each metric, and `available_date_ranges/0` / `default_date_range/0` back the filter UI.
- **Dashboard editor stories (not yet assigned)** will require adding CRUD functions to DashboardsRepository and VisualizationsRepository, and adding corresponding context functions for creating, updating, and deleting dashboards and visualizations. The schema layer is already in place.

## Issues

- **available_date_ranges/0 @spec range type**: The `:all_time` and `:custom` entries set range to `nil`, but the original spec had the range field typed as `{Date.t(), Date.t()}`. Fixed prior to this review to `{Date.t(), Date.t()} | nil` to accurately reflect the nil sentinel values.

## Conclusion

The MetricFlow.Dashboards context is ready for implementation of Story 441. The context API is complete and consistent, all dependencies and delegate targets are verified, type specs are accurate, and the schema layer is fully specified. The empty repository stubs are not a blocker. The two unused ChartBuilder functions (`build_bar_chart_spec/2` and `build_summary_card_spec/2`) should be revisited when dashboard editor stories arrive to confirm whether they belong here or will be called directly from a future LiveView.
