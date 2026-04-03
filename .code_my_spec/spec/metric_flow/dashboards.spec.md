# MetricFlow.Dashboards

Public API boundary for the Dashboards bounded context. Manages dashboard collections and standalone visualizations. Aggregates and shapes metric data from the Metrics context into chart-ready structures. Delegates Vega-Lite chart construction (single-metric and multi-series) to ChartBuilder. Delegates structured query building to QueryBuilder. Delegates integration presence checks to Integrations.

All public functions that require user isolation accept a `%Scope{}` as the first parameter. Pure utility functions (default_date_range/0, available_date_ranges/0) require no scope.

## Type

context

## Delegates

- build_chart_spec/2: MetricFlow.Dashboards.ChartBuilder.build_time_series_spec/2
- build_multi_series_chart_spec/2: MetricFlow.Dashboards.ChartBuilder.build_multi_series_spec/2
- build_area_chart_spec/2: MetricFlow.Dashboards.ChartBuilder.build_area_chart_spec/2
- build_bar_chart_spec/2: MetricFlow.Dashboards.ChartBuilder.build_bar_chart_spec/2

## Functions

### get_dashboard_data/2

Retrieves all data needed for a dashboard view for the scoped user. Calls Metrics for time series data and aggregated summary statistics, and Integrations for the list of connected platforms. Returns a unified map that the LiveView can render directly.

Supported options:
- `:platform` — filter metrics by provider atom (maps to `:provider` in Metrics)
- `:date_range` — `{start_date, end_date}` tuple; defaults to `default_date_range/0` when omitted
- `:metric_type` — filter metrics by type string

```elixir
@spec get_dashboard_data(Scope.t(), keyword()) ::
        {:ok,
         %{
           time_series:
             list(%{metric_name: String.t(), data: list(%{date: Date.t(), value: float()})}),
           summary_stats:
             list(%{
               metric_name: String.t(),
               stats: %{
                 sum: float(),
                 avg: float(),
                 min: float(),
                 max: float(),
                 count: integer()
               }
             }),
           available_filters: %{
             platforms: list(atom()),
             metric_types: list(String.t()),
             metric_names: list(String.t())
           },
           connected_platforms: list(atom()),
           applied_filters: keyword()
         }}
        | {:error, term()}
```

**Process**:
1. Extract `:date_range`, `:platform`, and `:metric_type` from opts, falling back to `default_date_range/0` for `:date_range` if not provided
2. Build `applied_filters` by merging the resolved date range into opts so callers can inspect the exact filters used
3. Call `Integrations.list_integrations/1` with the scope and map results to a list of provider atoms for `connected_platforms`
4. Construct `metric_query_opts` by conditionally including `:provider`, `:date_range`, and `:metric_type` based on which filters are non-nil
5. Resolve distinct metric names to query using a private helper that branches on the combination of platform and metric_type filters
6. For each resolved metric name, call `Metrics.query_time_series/3` and collect results into `time_series` entries of shape `%{metric_name, data}`
7. For each resolved metric name, call `Metrics.aggregate_metrics/3` and collect results into `summary_stats` entries of shape `%{metric_name, stats}`
8. Build `available_filters` with `platforms` from connected_platforms, `metric_types` as an empty list, and `metric_names` from `Metrics.list_metric_names/1` (all metrics, unfiltered)
9. Return `{:ok, %{time_series, summary_stats, available_filters, connected_platforms, applied_filters}}`

**Test Assertions**:
- returns an ok tuple with a map containing all five keys: time_series, summary_stats, available_filters, connected_platforms, applied_filters
- time_series contains one entry per distinct metric name for the scoped user
- summary_stats contains one entry per distinct metric name with sum, avg, min, max, and count keys
- connected_platforms reflects the provider atoms of the user's current integrations
- available_filters.platforms is derived from connected integrations
- available_filters.metric_names contains all distinct metric names for the user
- applies platform filter to both time_series and summary_stats, excluding metrics from other providers
- applies date_range filter to both time_series and summary_stats, excluding metrics outside the range
- applies metric_type filter to time_series and summary_stats, excluding metrics of other types
- uses default_date_range/0 when no date_range option is provided
- returns empty time_series and empty summary_stats when the user has no metrics
- applied_filters in the result reflects all opts used including the resolved date_range
- does not return data belonging to other users

### build_chart_spec/2

Builds a Vega-Lite JSON specification for a time series line chart for a single metric. The returned map is JSON-encodable and can be passed to vega-embed on the client for rendering. Delegates to MetricFlow.Dashboards.ChartBuilder.build_time_series_spec/2.

```elixir
@spec build_chart_spec(String.t(), list(%{date: Date.t(), value: float()})) :: map()
```

**Process**:
1. Delegate directly to `ChartBuilder.build_time_series_spec/2` with the metric_name and data arguments unchanged

**Test Assertions**:
- returns a map with a "$schema" key pointing to a Vega-Lite schema URL
- returned map includes a "mark" key configured for a line chart with type "line"
- returned map includes an "encoding" key with "x" mapped to the "date" field and "y" mapped to the "value" field
- title in the returned spec matches the metric_name argument
- returns a valid Vega-Lite spec for an empty data list
- data points in the spec have dates serialized as ISO 8601 strings

### build_multi_series_chart_spec/2

Builds a Vega-Lite JSON specification for a multi-series overlay line chart. Multiple metrics appear as differently colored lines on a single chart. Delegates to MetricFlow.Dashboards.ChartBuilder.build_multi_series_spec/2.

```elixir
@spec build_multi_series_chart_spec(String.t(), list(%{metric_name: String.t(), data: list(%{date: Date.t(), value: float()})})) :: map()
```

**Process**:
1. Delegate directly to `ChartBuilder.build_multi_series_spec/2` with the title and time_series arguments unchanged

**Test Assertions**:
- returns a map with a "$schema" key pointing to a Vega-Lite schema URL
- encoding includes "color" mapped to the "metric" field for per-metric line colors
- flattened data contains entries from all provided metrics
- returns a valid spec for an empty metrics list
- returns a valid spec for multiple metrics with overlapping date ranges

### default_date_range/0

Returns the default date range tuple used when no date range filter is specified. The end date is yesterday (to exclude the incomplete current day) and the start date is 30 days prior to the end date. This is a pure function with no side effects.

```elixir
@spec default_date_range() :: {Date.t(), Date.t()}
```

**Process**:
1. Compute `end_date` as `Date.utc_today()` minus 1 day
2. Compute `start_date` as `end_date` minus 30 days
3. Return `{start_date, end_date}`

**Test Assertions**:
- returns a two-element tuple of Date structs
- end_date is always yesterday relative to the current UTC date
- start_date is always 30 days before the end_date
- start_date is always before end_date

### available_date_ranges/0

Returns the list of preset date range options available in the filter UI. Each option includes an atom key, a human-readable label, and a range tuple `{start_date, end_date}` computed at call time. The `:all_time` and `:custom` entries have a nil range. This is a pure function with no side effects.

```elixir
@spec available_date_ranges() ::
        list(%{key: atom(), label: String.t(), range: {Date.t(), Date.t()} | nil})
```

**Process**:
1. Compute `yesterday` as `Date.utc_today()` minus 1 day
2. Build and return a list of five preset entries: `:last_7_days`, `:last_30_days`, `:last_90_days`, `:all_time`, and `:custom`
3. For `:last_7_days`, set range to `{yesterday - 6 days, yesterday}`
4. For `:last_30_days`, set range to `{yesterday - 29 days, yesterday}`
5. For `:last_90_days`, set range to `{yesterday - 89 days, yesterday}`
6. For `:all_time` and `:custom`, set range to nil

**Test Assertions**:
- returns a list with exactly 5 entries
- list contains entries with keys: :last_7_days, :last_30_days, :last_90_days, :all_time, :custom
- :last_7_days range spans 7 days (diff of 6) ending on yesterday
- :last_30_days range spans 30 days (diff of 29) ending on yesterday
- :last_90_days range spans 90 days (diff of 89) ending on yesterday
- :all_time range is nil
- :custom range is nil
- all bounded range end dates are yesterday, never today
- each entry has a non-empty label string

### has_integrations?/1

Checks whether the scoped user has any connected integrations. Used by the LiveView to decide whether to render the dashboard or an onboarding prompt.

```elixir
@spec has_integrations?(Scope.t()) :: boolean()
```

**Process**:
1. Call `Integrations.list_integrations/1` with the scope
2. Return true if the resulting list is non-empty, false otherwise

**Test Assertions**:
- returns true when the user has one or more integrations
- returns false when the user has no integrations
- does not count integrations belonging to other users

## Dependencies

- MetricFlow.Integrations
- MetricFlow.Metrics
- MetricFlow.Users.Scope

## Components

### MetricFlow.Dashboards.ChartBuilder

Pure module for building Vega-Lite chart specifications. Constructs single-metric line/bar/area charts, multi-series overlay charts with color encoding per metric, and summary stat card maps. All functions are pure transformations that accept data and return a JSON-encodable spec map with no side effects.

### MetricFlow.Dashboards.QueryBuilder

Pure module for building structured query parameters from filter inputs. Takes date range, platform, and metric name selections and returns keyword lists suitable for passing to Metrics context query functions. No side effects.

### MetricFlow.Dashboards.Dashboard

Ecto schema representing a named dashboard collection. Stores the dashboard name, owner reference, and a boolean flag indicating whether it is a built-in (canned) dashboard. Has many visualizations through DashboardVisualization.

### MetricFlow.Dashboards.DashboardVisualization

Ecto schema representing the join between a dashboard and a visualization. Tracks ordering and layout position of a visualization within a specific dashboard.

### MetricFlow.Dashboards.Visualization

Ecto schema representing a standalone Vega-Lite visualization. Stores the visualization name, owner reference, the Vega-Lite spec map, query parameters used to generate the spec, and a boolean flag indicating whether the visualization is shareable.

### MetricFlow.Dashboards.DashboardsRepository

Data access layer for dashboard persistence. Handles all Repo interactions for Dashboard schemas, including CRUD operations, scoped queries, and canned dashboard listing.

### MetricFlow.Dashboards.VisualizationsRepository

Data access layer for Visualization records. Handles listing, creating, updating, and deleting visualizations for a given user scope.

