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

  use Boundary, deps: [MetricFlow], exports: [Metric, DerivedMetricDefinition]

  alias MetricFlow.Metrics.MetricRepository
  alias MetricFlow.Metrics.ReviewMetrics
  alias MetricFlow.Metrics.EntityMetricRepository

  defdelegate channel_time_series(scope, opts),
    to: MetricFlow.Metrics.ChannelProjection,
    as: :series

  defdelegate channel_summary(series), to: MetricFlow.Metrics.ChannelProjection, as: :summary

  defdelegate aggregate_channel_points(points, semantics),
    to: MetricFlow.Metrics.ChannelProjection,
    as: :aggregate_points

  defdelegate youtube_metric_names(family),
    to: MetricFlow.Metrics.YouTubeMetricDefinitions,
    as: :names

  defdelegate persist_entity_report(
                scope,
                entity_id,
                family,
                breakdown,
                range,
                observations,
                fetched_at
              ),
              to: EntityMetricRepository

  defdelegate get_entity_cursor(scope, entity_id, family, timezone, breakdown),
    to: EntityMetricRepository

  defdelegate list_entity_observations(scope, entity_id), to: EntityMetricRepository

  defdelegate upsert_video(scope, channel_id, external_id, attrs),
    to: MetricFlow.Metrics.VideoEntityRepository

  defdelegate get_video(scope, entity_id), to: MetricFlow.Metrics.VideoEntityRepository
  defdelegate list_videos(scope, channel_id), to: MetricFlow.Metrics.VideoEntityRepository

  defdelegate upsert_channel(scope, external_id, attrs), to: EntityMetricRepository
  defdelegate get_channel(scope, entity_id), to: EntityMetricRepository
  defdelegate list_channels(scope), to: EntityMetricRepository
  defdelegate list_observations(scope, entity_id), to: EntityMetricRepository
  defdelegate get_cursor(scope, entity_id, family, timezone), to: EntityMetricRepository

  defdelegate persist_report(scope, entity_id, family, range, observations, fetched_at),
    to: EntityMetricRepository

  # ---------------------------------------------------------------------------
  # Delegated repository functions
  # ---------------------------------------------------------------------------

  defdelegate create_metric(scope, attrs), to: MetricRepository
  defdelegate create_metrics(scope, attrs_list), to: MetricRepository
  defdelegate list_metrics(scope), to: MetricRepository
  defdelegate list_metrics(scope, opts), to: MetricRepository
  defdelegate get_metric(scope, id), to: MetricRepository
  defdelegate query_time_series(scope, metric_name, opts), to: MetricRepository
  defdelegate list_providers_for_metric(scope, metric_name, opts \\ []), to: MetricRepository
  defdelegate get_latest_metric_date(scope), to: MetricRepository
  defdelegate get_latest_metric_date(scope, provider), to: MetricRepository
  defdelegate aggregate_metrics(scope, metric_name, opts), to: MetricRepository
  defdelegate list_metric_names(scope), to: MetricRepository
  defdelegate list_metric_names(scope, opts), to: MetricRepository
  defdelegate list_normalized_metric_names(scope), to: MetricRepository
  defdelegate list_normalized_metric_names(scope, opts), to: MetricRepository
  defdelegate delete_metrics_by_provider(scope, provider), to: MetricRepository
  defdelegate delete_all_metrics(scope), to: MetricRepository

  defdelegate delete_metrics_by_location_and_date(scope, provider, location_id, date),
    to: MetricRepository

  defdelegate list_metric_providers(scope), to: MetricRepository
  defdelegate list_metric_providers(scope, opts), to: MetricRepository
  defdelegate list_derived_metric_definitions(scope), to: MetricRepository
  defdelegate create_derived_metric_definition(scope, attrs), to: MetricRepository

  # ---------------------------------------------------------------------------
  # Rolling review metrics
  # ---------------------------------------------------------------------------

  defdelegate query_rolling_review_metrics(scope), to: ReviewMetrics
  defdelegate query_rolling_review_metrics(scope, opts), to: ReviewMetrics
end
