# MetricFlow.Reviews

Platform-agnostic review storage, retrieval, and rolling metric aggregation. Reviews are synced from external platforms (Google Business Profile, and future sources like Yelp, Trustpilot) into a dedicated `reviews` table with full review data. The context computes rolling review metrics (daily count, running total, rolling average rating) from this table.

All public functions accept a `%Scope{}` as the first parameter for multi-tenant isolation.

## Type

context

## Delegates

- list_reviews/2: MetricFlow.Reviews.ReviewRepository.list_reviews/2
- get_review/2: MetricFlow.Reviews.ReviewRepository.get_review/2
- create_reviews/2: MetricFlow.Reviews.ReviewRepository.create_reviews/2
- delete_reviews_by_provider/2: MetricFlow.Reviews.ReviewRepository.delete_reviews_by_provider/2

## Functions

### query_rolling_review_metrics/2

Computes rolling review metrics from the reviews table. Returns daily review count, running total count, and rolling average star rating as date-keyed time series.

```elixir
@spec query_rolling_review_metrics(Scope.t(), keyword()) :: %{
  review_count: list(%{date: Date.t(), value: float()}),
  review_total_count: list(%{date: Date.t(), value: float()}),
  review_average_rating: list(%{date: Date.t(), value: float()})
}
```

**Process**:
1. Query reviews table grouped by date, computing daily count and rating sum
2. Optionally filter by `:date_range` and `:provider` options
3. Compute rolling metrics via reduce: daily count, running total, rolling average
4. Return map with three keys, each containing date-sorted time series

**Test Assertions**:
- returns empty lists when no reviews exist
- computes correct daily review count
- computes correct running total count across multiple days
- computes correct rolling average rating
- filters by date range when provided
- filters by provider when provided
- aggregates across all providers when no provider filter

### review_count/1

Returns total number of reviews for the scoped user.

```elixir
@spec review_count(Scope.t()) :: non_neg_integer()
```

**Process**:
1. Delegate to ReviewRepository.count_reviews/1

**Test Assertions**:
- returns 0 when no reviews exist
- returns correct count across all providers

### recent_reviews/2

Returns the most recent reviews for the scoped user, optionally filtered by provider.

```elixir
@spec recent_reviews(Scope.t(), keyword()) :: list(Review.t())
```

**Process**:
1. Delegate to ReviewRepository.list_reviews/2 with limit (default 10) and provider filter
2. Order by review_date descending

**Test Assertions**:
- returns reviews ordered by most recent first
- respects limit option
- filters by provider when specified
- returns empty list when no reviews exist

## Dependencies

- MetricFlow.Reviews.ReviewRepository
- MetricFlow.Reviews.ReviewMetrics
- MetricFlow.Reviews.Review

## Components

### MetricFlow.Reviews.Review

Ecto schema representing an individual customer review from any platform. Stores the full review data including reviewer identity, star rating, comment text, and provider-specific metadata. Indexed for efficient queries by user, provider, date, and external ID (for deduplication during sync).

### MetricFlow.Reviews.ReviewRepository

Data access layer for Review CRUD and query operations. All queries are scoped via Scope struct for multi-tenant isolation. Provides bulk upsert for sync (deduplicates on external_review_id), listing with filter options (provider, location_id, date_range, limit, offset), total count, and provider-scoped deletion.

### MetricFlow.Reviews.ReviewMetrics

Pure computation module for rolling review metrics. Queries daily review aggregates from the database and computes running totals and rolling averages in Elixir. No side effects — takes query results and returns computed time series.
