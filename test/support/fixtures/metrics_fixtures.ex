defmodule MetricFlowTest.MetricsFixtures do
  @moduledoc """
  Test helpers for creating metric entities for testing.
  """

  alias MetricFlow.Metrics.Metric
  alias MetricFlow.Metrics.NormalizedMetric
  alias MetricFlow.Repo

  @doc """
  Inserts a metric record for the given user with optional attribute overrides.

  Defaults to a "sessions" traffic metric from Google Analytics recorded
  yesterday so it falls within the default 30-day range.
  """
  def insert_metric!(user, attrs \\ %{}) do
    yesterday = Date.add(Date.utc_today(), -1)

    defaults = %{
      user_id: user.id,
      metric_type: "traffic",
      metric_name: "sessions",
      value: 100.0,
      recorded_at: DateTime.new!(yesterday, ~T[00:00:00], "Etc/UTC"),
      provider: :google_analytics,
      dimensions: %{}
    }

    %Metric{}
    |> Metric.changeset(with_normalized_name(Map.merge(defaults, attrs)))
    |> Repo.insert!()
  end

  # `normalized_metric_name` is derived, not defaulted, because the read path
  # depends on it and a fixture that omitted it was building a row that cannot
  # exist in production. All six `DataSync.DataProviders` modules set it through
  # `NormalizedMetric.normalize/2` on every metric they write, and
  # `MetricRepository.list_normalized_metric_names/2` filters
  # `not is_nil(normalized_metric_name)` — so a metric without one is invisible
  # to every dashboard, every filter list and the LLM context, and the whole
  # dashboard reads as empty. An explicit override still wins.
  defp with_normalized_name(attrs) do
    Map.put_new_lazy(attrs, :normalized_metric_name, fn ->
      NormalizedMetric.normalize(
        Map.fetch!(attrs, :provider),
        Map.fetch!(attrs, :metric_name)
      )
    end)
  end

  @doc """
  Inserts a "sessions" and a "clicks" metric for the given user, matching
  the metric names used in the editor test suite.
  """
  def insert_editor_test_metrics!(user) do
    yesterday = Date.add(Date.utc_today(), -1)

    sessions = insert_metric!(user, %{
      metric_name: "sessions",
      metric_type: "traffic",
      recorded_at: DateTime.new!(yesterday, ~T[00:00:00], "Etc/UTC")
    })

    clicks = insert_metric!(user, %{
      metric_name: "clicks",
      metric_type: "advertising",
      provider: :google_ads,
      recorded_at: DateTime.new!(yesterday, ~T[00:00:00], "Etc/UTC")
    })

    {sessions, clicks}
  end
end
