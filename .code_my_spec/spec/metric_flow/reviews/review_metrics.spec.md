# MetricFlow.Reviews.ReviewMetrics

Computes rolling review metrics from the reviews table. Provides query_rolling_review_metrics/2 which returns daily review count, running total count, and rolling average star rating as date-keyed time series. Platform-agnostic — aggregates across all providers. Used by provider dashboards and the correlation engine.

## Type

module

## Dependencies

- MetricFlow.Reviews.Review

## Functions

