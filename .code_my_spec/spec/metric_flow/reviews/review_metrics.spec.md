# MetricFlow.Reviews.ReviewMetrics

Computes rolling review metrics from the reviews table. Provides query_rolling_review_metrics/2 which returns daily review count, running total count, and rolling average star rating as date-keyed time series. Platform-agnostic — aggregates across all providers. Used by provider dashboards and the correlation engine.

## Type

module

## Delegates

_None_

## Functions

### query_rolling_review_metrics/2

Returns computed rolling review metrics for the scoped user, derived from the reviews table.

Queries all rows from the `reviews` table belonging to the user (optionally filtered by date range) and returns a map with three keys: `:review_count`, `:review_total_count`, and `:review_average_rating`. Each key maps to a list of `%{date, value}` maps sorted by date ascending, covering only dates that have at least one review. Aggregates across all providers.

```elixir
@spec query_rolling_review_metrics(Scope.t(), keyword()) :: %{
  review_count: list(%{date: Date.t(), value: float()}),
  review_total_count: list(%{date: Date.t(), value: float()}),
  review_average_rating: list(%{date: Date.t(), value: float()})
}
```

**Process**:
1. Extract the user ID from the `%Scope{}` struct
2. Fetch daily review aggregates from the `reviews` table, grouped by `review_date`, counting rows and summing `star_rating` per day, applying any `date_range: {start_date, end_date}` option if provided, ordered by date ascending
3. Reduce over the sorted daily rows to compute rolling metrics: daily review count, cumulative running total count, and rolling average star rating accumulated across all days
4. Return a map with three keys — `:review_count`, `:review_total_count`, and `:review_average_rating` — each a list of `%{date: Date.t(), value: float()}` maps sorted ascending by date

**Test Assertions**:
- returns a map with keys `:review_count`, `:review_total_count`, and `:review_average_rating`
- returns empty lists for all three keys when no reviews exist for the user
- `:review_count` contains one entry per day with the count of reviews received on that day as a float
- `:review_total_count` contains a running cumulative count across all days
- `:review_average_rating` contains the rolling average star rating up to each day
- accepts a `date_range: {start_date, end_date}` option and filters results to that range
- returns results sorted by date ascending
- does not include reviews belonging to other users
- handles days with reviews but no star rating (rating defaults to 0.0)
- rolling average correctly weights ratings accumulated across multiple days
- aggregates reviews from all providers without filtering by provider

## Dependencies

- MetricFlow.Reviews.Review
- MetricFlow.Repo
- MetricFlow.Users.Scope
