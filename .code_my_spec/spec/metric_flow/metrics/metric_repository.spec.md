# MetricFlow.Metrics.MetricRepository

Data access layer for Metric CRUD and query operations filtered by user_id. All operations are scoped via Scope struct for multi-tenant isolation. Provides list_metrics/2 with filter options (provider, metric_type, metric_name, date_range, limit, offset), get_metric/2, create_metric/2, create_metrics/2 for bulk insert, delete_metrics_by_provider/2, query_time_series/3 for date-grouped aggregation, aggregate_metrics/3 for summary statistics, and list_metric_names/2 for distinct name discovery.
