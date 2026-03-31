defmodule MetricFlow.Metrics do
  @moduledoc """
  Public API boundary for the Metrics bounded context.

  Manages unified metric data points aggregated from external providers such as
  Google Analytics, Google Ads, Facebook Ads, and QuickBooks. Each metric
  captures a single time-series observation with a type, name, value,
  timestamp, originating provider, and optional dimension breakdowns.

  Also provides computed rolling review metrics derived from raw review rows
  stored with `metric_type = "reviews"`.

  All public functions accept a `%Scope{}` as the first parameter for
  multi-tenant isolation.
  """

  use Boundary, deps: [MetricFlow], exports: [Metric]

  alias MetricFlow.Metrics.MetricRepository
  alias MetricFlow.Metrics.ReviewMetrics

  # ---------------------------------------------------------------------------
  # Delegated repository functions
  # ---------------------------------------------------------------------------

  defdelegate create_metric(scope, attrs), to: MetricRepository
  defdelegate create_metrics(scope, attrs_list), to: MetricRepository
  defdelegate list_metrics(scope), to: MetricRepository
  defdelegate list_metrics(scope, opts), to: MetricRepository
  defdelegate get_metric(scope, id), to: MetricRepository
  defdelegate query_time_series(scope, metric_name, opts), to: MetricRepository
  defdelegate aggregate_metrics(scope, metric_name, opts), to: MetricRepository
  defdelegate list_metric_names(scope), to: MetricRepository
  defdelegate list_metric_names(scope, opts), to: MetricRepository
  defdelegate delete_metrics_by_provider(scope, provider), to: MetricRepository
  defdelegate list_metric_providers(scope), to: MetricRepository
  defdelegate list_metric_providers(scope, opts), to: MetricRepository

  # ---------------------------------------------------------------------------
  # Rolling review metrics
  # ---------------------------------------------------------------------------

  defdelegate query_rolling_review_metrics(scope), to: ReviewMetrics
  defdelegate query_rolling_review_metrics(scope, opts), to: ReviewMetrics
end
