# MetricFlowWeb.CorrelationLive

Correlation analysis UI views.

## Type

live_context

## LiveViews

### CorrelationLive.Index

- **Route:** `/correlations`
- **Description:** Displays Pearson correlation results between metrics and a goal metric. Shows Raw mode (ranked, sortable table of all correlations) and Smart mode (AI-powered recommendations with feedback). Includes empty state, progress banner during correlation runs, and manual trigger for new runs.

### CorrelationLive.Goals

- **Route:** `/correlations/goals`
- **Description:** Configures the goal metric used by the correlation engine. Allows selecting which metric all other metrics are correlated against.

## Components

None — each LiveView is self-contained.

## Dependencies

- MetricFlow.Correlations
- MetricFlow.Metrics
