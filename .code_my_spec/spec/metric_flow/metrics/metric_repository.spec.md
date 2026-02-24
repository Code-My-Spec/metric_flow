# MetricFlow.Metrics.MetricRepository

Data access layer for Metric CRUD and query operations filtered by user_id. All operations are scoped via Scope struct for multi-tenant isolation. Provides list_metrics/2 with filter options (provider, metric_type, metric_name, date_range, limit, offset), get_metric/2, create_metric/2, create_metrics/2 for bulk insert, delete_metrics_by_provider/2, query_time_series/3 for date-grouped aggregation, aggregate_metrics/3 for summary statistics, and list_metric_names/2 for distinct name discovery.

## Functions

### list_metrics/2

Returns all metrics for the scoped user with optional filter and pagination options. Filters by provider, metric_type, metric_name, or date_range, with limit/offset for pagination. Results are ordered by recorded_at descending.

```elixir
@spec list_metrics(Scope.t(), keyword()) :: list(Metric.t())
```

**Process**:
1. Build base query filtering by user_id from scope
2. Apply optional provider filter when provider key is present in opts
3. Apply optional metric_type filter when metric_type key is present in opts
4. Apply optional metric_name filter when metric_name key is present in opts
5. Apply optional date_range filter as {start_date, end_date} tuple when date_range key is present in opts
6. Order results by recorded_at descending
7. Apply optional limit when limit key is present in opts
8. Apply optional offset when offset key is present in opts
9. Execute query with Repo.all()
10. Return list of metrics (empty list if none exist)

**Test Assertions**:
- returns list of metrics for scoped user
- returns empty list when user has no metrics
- filters by provider when provider option is provided
- filters by metric_type when metric_type option is provided
- filters by metric_name when metric_name option is provided
- filters by date range when date_range option is provided as {start_date, end_date}
- applies limit when limit option is provided
- applies offset when offset option is provided
- metrics are ordered by recorded_at descending
- does not return metrics belonging to other users
- enforces multi-tenant isolation

### get_metric/2

Retrieves a single metric record by ID for the scoped user.

```elixir
@spec get_metric(Scope.t(), integer()) :: {:ok, Metric.t()} | {:error, :not_found}
```

**Process**:
1. Build query filtering by user_id from scope and the given id
2. Execute query with Repo.one()
3. Return {:error, :not_found} if nil
4. Return {:ok, metric} if found

**Test Assertions**:
- returns ok tuple with metric when metric exists for scoped user
- returns error tuple with :not_found when metric id does not exist
- returns error tuple with :not_found when metric belongs to a different user
- enforces multi-tenant isolation

### create_metric/2

Inserts a single metric record for the scoped user.

```elixir
@spec create_metric(Scope.t(), map()) :: {:ok, Metric.t()} | {:error, Ecto.Changeset.t()}
```

**Process**:
1. Merge user_id from scope into attrs
2. Build changeset with Metric.changeset/2
3. Insert metric record with Repo.insert/1
4. Return {:ok, metric} on success or {:error, changeset} on validation failure

**Test Assertions**:
- creates metric record with valid attributes
- associates metric with user_id from scope
- stores metric_type, metric_name, value, recorded_at, and provider
- stores dimensions as embedded map
- returns error changeset when metric_type is missing
- returns error changeset when metric_name is missing
- returns error changeset when value is missing
- returns error changeset when provider is missing
- returns error changeset when recorded_at is missing
- does not allow inserting metrics for a different user than the scope

### create_metrics/2

Bulk-inserts a list of metric attribute maps for the scoped user in a single database operation.

```elixir
@spec create_metrics(Scope.t(), list(map())) :: {:ok, integer()} | {:error, term()}
```

**Process**:
1. Add user_id from scope to each metric map in the list
2. Add inserted_at and updated_at timestamps to each metric map
3. Execute Repo.insert_all/2 with the prepared list
4. Return {:ok, count} where count is the number of inserted records

**Test Assertions**:
- returns ok tuple with count of inserted metrics
- associates all metrics with user_id from scope
- inserts all metrics in a single database operation
- returns {:ok, 0} for empty list input
- sets inserted_at and updated_at timestamps on all inserted records
- does not insert any records when the list is empty

### delete_metrics_by_provider/2

Deletes all metric records for the scoped user belonging to a specific provider. Used when a provider integration is disconnected.

```elixir
@spec delete_metrics_by_provider(Scope.t(), atom()) :: {:ok, integer()}
```

**Process**:
1. Build query filtering by user_id from scope and the given provider
2. Execute Repo.delete_all/1
3. Return {:ok, count} where count is the number of deleted records

**Test Assertions**:
- returns ok tuple with count of deleted metrics
- deletes only metrics matching the specified provider for the scoped user
- does not delete metrics from other providers
- does not delete metrics belonging to other users
- returns {:ok, 0} when no metrics match the provider
- enforces multi-tenant isolation

### query_time_series/3

Returns metric values as a time series grouped by date for a given metric name. Sums values per date and orders by date ascending. Used by dashboards for charting and by correlations for analysis.

```elixir
@spec query_time_series(Scope.t(), String.t(), keyword()) :: list(%{date: Date.t(), value: float()})
```

**Process**:
1. Build base query filtering by user_id from scope and the given metric_name
2. Apply optional provider filter when provider key is present in opts
3. Apply date_range filter; default to last 30 days when date_range not provided
4. Group results by date using fragment to truncate recorded_at to date precision
5. Select date and summed value per group
6. Order by date ascending
7. Execute query with Repo.all()
8. Return list of maps with date and value keys

**Test Assertions**:
- returns list of date/value maps for matching metrics
- groups values by date and sums them within each date
- orders results by date ascending
- filters by provider when provider option is provided
- defaults to last 30 days when date_range option is not provided
- filters by date range when date_range option is provided as {start_date, end_date}
- returns empty list when no matching metrics are found
- does not include metrics from other users
- enforces multi-tenant isolation

### aggregate_metrics/3

Returns aggregated statistics (sum, average, min, max, count) for a given metric name. Used by dashboards for summary stats and by AI context for insights.

```elixir
@spec aggregate_metrics(Scope.t(), String.t(), keyword()) :: %{sum: float(), avg: float(), min: float(), max: float(), count: integer()}
```

**Process**:
1. Build base query filtering by user_id from scope and the given metric_name
2. Apply optional provider filter when provider key is present in opts
3. Apply optional date_range filter when date_range key is present in opts
4. Select sum, avg, min, max, and count aggregations over the value field
5. Execute query with Repo.one()
6. Return map with sum, avg, min, max, and count keys
7. Return zeroed map (sum: 0.0, avg: 0.0, min: 0.0, max: 0.0, count: 0) when no records match

**Test Assertions**:
- returns map with sum, avg, min, max, and count keys
- calculates correct sum of metric values
- calculates correct average of metric values
- returns correct min and max values
- returns correct count of matching records
- filters by provider when provider option is provided
- filters by date range when date_range option is provided
- returns zeroed map when no matching metrics are found
- does not include metrics from other users
- enforces multi-tenant isolation

### list_metric_names/2

Returns a sorted list of distinct metric names available for the scoped user. Used by Goals UI for metric selection and dashboard configuration.

```elixir
@spec list_metric_names(Scope.t(), keyword()) :: list(String.t())
```

**Process**:
1. Build base query filtering by user_id from scope
2. Apply optional provider filter when provider key is present in opts
3. Select distinct metric_name values
4. Order alphabetically ascending
5. Execute query with Repo.all()
6. Return list of metric name strings (empty list if none exist)

**Test Assertions**:
- returns list of distinct metric names for scoped user
- does not contain duplicate metric names
- filters by provider when provider option is provided
- returns empty list when user has no metrics
- orders names alphabetically
- does not include metric names from other users
- enforces multi-tenant isolation

## Dependencies

- Ecto.Query
- MetricFlow.Infrastructure.Repo
- MetricFlow.Users.Scope
- MetricFlow.Metrics.Metric
