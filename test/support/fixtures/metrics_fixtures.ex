defmodule MetricFlowTest.MetricsFixtures do
  @moduledoc """
  Test helpers for creating metric entities for testing.
  """

  alias MetricFlow.Metrics.Metric
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
    |> Metric.changeset(Map.merge(defaults, attrs))
    |> Repo.insert!()
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
