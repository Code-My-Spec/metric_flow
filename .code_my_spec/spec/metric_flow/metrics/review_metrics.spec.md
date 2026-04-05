# MetricFlow.Metrics.ReviewMetrics

Computes rolling review metrics from raw review data stored in the metrics table. Derives three platform-agnostic computed metrics from rows where `metric_type = "reviews"`: daily review count, running total count, and rolling average star rating. All computation is performed in Elixir after fetching daily aggregates from the database, making these metrics provider-agnostic.

## Delegates

_None_

## Functions

### query_rolling_review_metrics/2

Returns computed rolling review metrics for the scoped user.

Queries all `metric_type = "reviews"` rows from the metrics table, optionally filtered by date range, and returns a map with three keys: `:review_count`, `:review_total_count`, and `:review_average_rating`. Each key maps to a list of `%{date, value}` maps sorted by date ascending, covering only dates that have at least one review.

```elixir
@spec query_rolling_review_metrics(Scope.t(), keyword()) :: %{
  review_count: list(%{date: Date.t(), value: float()}),
  review_total_count: list(%{date: Date.t(), value: float()}),
  review_average_rating: list(%{date: Date.t(), value: float()})
}
```

**Process**:
1. Extract the user ID from the `%Scope{}` struct
2. Fetch daily review aggregates from the database, grouped by date and filtered by `metric_type = "reviews"`, applying any `date_range` option if provided
3. Reduce over the sorted daily rows to compute rolling metrics: daily count, running total count, and rolling average rating accumulated across all days
4. Return a map with the three metric series, each sorted ascending by date

**Test Assertions**:
- returns a map with keys `:review_count`, `:review_total_count`, and `:review_average_rating`
- returns empty lists for all three keys when no review metrics exist for the user
- `:review_count` contains one entry per day with the count of reviews for that day
- `:review_total_count` contains a running cumulative count across all days
- `:review_average_rating` contains the rolling average star rating up to each day
- accepts a `date_range: {start_date, end_date}` option and filters results to that range
- returns results sorted by date ascending
- does not include results from other users
- handles days with review_count rows but no review_rating rows (rating defaults to 0.0)
- rolling average correctly weights ratings across multiple days

## Dependencies

- MetricFlow.Metrics.Metric
- MetricFlow.Repo
- MetricFlow.Users.Scope
