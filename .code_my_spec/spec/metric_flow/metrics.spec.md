# MetricFlow.Metrics

Unified metric storage and retrieval. Persists metrics from external data providers (Google Analytics, Google Ads, Facebook Ads, QuickBooks) in a normalized format and exposes query functions for dashboards, correlations, AI insights, and goal tracking. All operations are scoped to the current user via Scope struct for multi-tenant isolation.

## Type

context

## Delegates

- create_metric/2: MetricFlow.Metrics.MetricRepository.create_metric/2
- create_metrics/2: MetricFlow.Metrics.MetricRepository.create_metrics/2
- list_metrics/2: MetricFlow.Metrics.MetricRepository.list_metrics/2
- get_metric/2: MetricFlow.Metrics.MetricRepository.get_metric/2
- query_time_series/3: MetricFlow.Metrics.MetricRepository.query_time_series/3
- aggregate_metrics/3: MetricFlow.Metrics.MetricRepository.aggregate_metrics/3
- list_metric_names/2: MetricFlow.Metrics.MetricRepository.list_metric_names/2
- delete_metrics_by_provider/2: MetricFlow.Metrics.MetricRepository.delete_metrics_by_provider/2

## Functions

### create_metric/2

Persists a single metric record for the scoped user. Called by DataSync.SyncWorker after fetching and transforming provider data.

```elixir
@spec create_metric(Scope.t(), map()) :: {:ok, Metric.t()} | {:error, Ecto.Changeset.t()}
```

**Process**:
1. Delegate to MetricRepository.create_metric/2
2. Return ok tuple with metric or error with changeset

**Test Assertions**:
- returns ok tuple with metric for valid attrs
- associates metric with user_id from scope
- stores metric_type, metric_name, value, recorded_at, provider
- stores dimensions as embedded map
- returns error changeset when metric_type is missing
- returns error changeset when metric_name is missing
- returns error changeset when value is missing
- returns error changeset when provider is missing

### create_metrics/2

Bulk-inserts a list of metric maps for the scoped user. Used by SyncWorker for efficient batch persistence.

```elixir
@spec create_metrics(Scope.t(), list(map())) :: {:ok, integer()} | {:error, term()}
```

**Process**:
1. Delegate to MetricRepository.create_metrics/2
2. Return ok tuple with count of inserted records

**Test Assertions**:
- returns ok tuple with count of inserted metrics
- associates all metrics with user_id from scope
- inserts all metrics in a single database operation
- returns {:ok, 0} for empty list
- sets inserted_at and updated_at timestamps on all records

### list_metrics/2

Lists metrics for the scoped user with optional filters. Delegates to MetricRepository.

```elixir
@spec list_metrics(Scope.t(), keyword()) :: list(Metric.t())
```

**Process**:
1. Delegate to MetricRepository.list_metrics/2

**Test Assertions**:
- returns list of metrics for scoped user
- returns empty list when user has no metrics
- filters by provider when provider option provided
- filters by metric_type when metric_type option provided
- filters by metric_name when metric_name option provided
- filters by date range when date_range option provided as {start_date, end_date}
- applies limit when limit option provided
- applies offset when offset option provided
- metrics are ordered by recorded_at descending
- does not return metrics belonging to other users

### get_metric/2

Retrieves a specific metric record for the scoped user. Delegates to MetricRepository.

```elixir
@spec get_metric(Scope.t(), integer()) :: {:ok, Metric.t()} | {:error, :not_found}
```

**Process**:
1. Delegate to MetricRepository.get_metric/2

**Test Assertions**:
- returns ok tuple with metric when found
- returns error tuple with :not_found when metric doesn't exist
- returns error tuple with :not_found when metric belongs to different user

### query_time_series/3

Returns metric values as a time series for a given metric name, grouped by date. Used by dashboards for charting and correlations for analysis.

```elixir
@spec query_time_series(Scope.t(), String.t(), keyword()) :: list(%{date: Date.t(), value: float()})
```

**Process**:
1. Delegate to MetricRepository.query_time_series/3

**Test Assertions**:
- returns list of date/value maps for matching metrics
- groups values by date and sums them
- orders by date ascending
- filters by provider when provider option provided
- defaults to last 30 days when date_range not provided
- filters by date range when date_range option provided
- returns empty list when no matching metrics found
- does not include metrics from other users

### aggregate_metrics/3

Returns aggregated metric values (sum, average, min, max, count) for a given metric name. Used by dashboards for summary stats and AI for insights.

```elixir
@spec aggregate_metrics(Scope.t(), String.t(), keyword()) :: %{sum: float(), avg: float(), min: float(), max: float(), count: integer()}
```

**Process**:
1. Delegate to MetricRepository.aggregate_metrics/3

**Test Assertions**:
- returns map with sum, avg, min, max, count keys
- calculates correct sum of metric values
- calculates correct average of metric values
- returns min and max values
- returns count of matching records
- filters by provider when provider option provided
- filters by date range when date_range option provided
- returns zeroed map when no matching metrics found

### list_metric_names/2

Returns distinct metric names available for the scoped user. Used by Goals UI for metric selection and dashboard configuration.

```elixir
@spec list_metric_names(Scope.t(), keyword()) :: list(String.t())
```

**Process**:
1. Delegate to MetricRepository.list_metric_names/2

**Test Assertions**:
- returns list of distinct metric names
- does not contain duplicates
- filters by provider when provider option provided
- returns empty list when user has no metrics
- orders names alphabetically
- does not include metric names from other users

### delete_metrics_by_provider/2

Deletes all metrics for the scoped user from a specific provider. Used when an integration is disconnected. Delegates to MetricRepository.

```elixir
@spec delete_metrics_by_provider(Scope.t(), atom()) :: {:ok, integer()}
```

**Process**:
1. Delegate to MetricRepository.delete_metrics_by_provider/2

**Test Assertions**:
- returns ok tuple with count of deleted metrics
- deletes only metrics for the specified provider
- does not delete metrics from other providers
- does not delete metrics belonging to other users
- returns {:ok, 0} when no metrics match

## Dependencies

- MetricFlow.Users
- MetricFlow.Metrics.MetricRepository

## Components

### MetricFlow.Metrics.Metric

Ecto schema representing a unified metric data point. Stores metric_type (category like "traffic", "advertising", "financial"), metric_name (specific metric like "sessions", "clicks", "revenue"), value as float, recorded_at timestamp, provider atom matching Integration provider enum, and dimensions as embedded map for dimension breakdowns (source, campaign, page, etc.). Belongs to User. Indexed on [user_id, provider], [user_id, metric_name, recorded_at], and [user_id, metric_type].

### MetricFlow.Metrics.MetricRepository

Data access layer for Metric CRUD and query operations filtered by user_id. All operations are scoped via Scope struct for multi-tenant isolation. Provides list_metrics/2 with filter options (provider, metric_type, metric_name, date_range, limit, offset), get_metric/2, create_metric/2, create_metrics/2 for bulk insert, delete_metrics_by_provider/2, query_time_series/3 for date-grouped aggregation, aggregate_metrics/3 for summary statistics, and list_metric_names/2 for distinct name discovery.

