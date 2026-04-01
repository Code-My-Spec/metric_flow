# MetricFlow.Reviews

Platform-agnostic review storage, retrieval, and rolling metric aggregation. Reviews are synced from external platforms (Google Business Profile, and future sources like Yelp, Trustpilot) into a dedicated reviews table with full review data (reviewer, rating, comment, date). The context computes rolling review metrics (daily count, running total, rolling average rating) from this table. All public functions accept a `%Scope{}` as the first parameter for multi-tenant isolation.

## Type

context

## Dependencies

- MetricFlow.Reviews.ReviewMetrics
- MetricFlow.Reviews.ReviewRepository

## Functions

