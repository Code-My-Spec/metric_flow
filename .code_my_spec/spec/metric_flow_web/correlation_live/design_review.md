# Design Review

## Overview

Reviewed MetricFlowWeb.CorrelationLive context with 2 child LiveViews: Index and Goals. The architecture is sound with clear separation of concerns between viewing correlation results and configuring the goal metric.

## Architecture

- Clean separation: Index handles result display (Raw/Smart modes), Goals handles goal metric configuration
- Index depends on MetricFlow.Correlations and MetricFlow.Correlations.CorrelationResult (struct aliased for pattern matching in templates — standard Phoenix pattern)
- Goals depends on MetricFlow.Metrics (for metric names dropdown) and MetricFlow.Correlations (for running correlations and reading current goal)
- Both LiveViews are self-contained with no shared components, appropriate for two distinct pages
- No architectural concerns — dependencies point to domain contexts only

## Integration

- Goals redirects to `/correlations` (Index) after saving, creating a natural workflow: configure goal → view results
- Index links to `/integrations` in empty state, guiding users to connect data sources first
- Index links to `/insights` from Smart mode, connecting to the AI Insights feature
- Both views scope all context calls via `current_scope` for multi-tenant isolation
- PubSub not used — Index polls state on mount via `get_latest_correlation_summary/1` and `list_correlation_jobs/1`

## Conclusion

The CorrelationLive context is ready for implementation. All dependencies are verified, specs are consistent, and no issues were found.
