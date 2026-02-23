# MetricFlow.Metrics.Metric

Ecto schema representing a unified metric data point. Stores metric_type (category like "traffic", "advertising", "financial"), metric_name (specific metric like "sessions", "clicks", "revenue"), value as float, recorded_at timestamp, provider atom matching Integration provider enum, and dimensions as embedded map for dimension breakdowns (source, campaign, page, etc.). Belongs to User. Indexed on [user_id, provider], [user_id, metric_name, recorded_at], and [user_id, metric_type].
