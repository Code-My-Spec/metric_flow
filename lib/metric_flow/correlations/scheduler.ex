defmodule MetricFlow.Correlations.Scheduler do
  @moduledoc """
  Oban scheduled job that recalculates correlations daily for every user
  with sufficient data.

  Triggered by Oban.Plugins.Cron shortly after the daily data sync
  (MetricFlow.DataSync.Scheduler) runs, so correlations are recalculated
  against freshly synced data without requiring a user to click Run Now.
  """

  use Oban.Worker,
    queue: :correlations,
    max_attempts: 1

  alias MetricFlow.Correlations

  @impl Oban.Worker
  @spec perform(Oban.Job.t()) :: :ok
  def perform(%Oban.Job{}) do
    {:ok, _count} = Correlations.schedule_daily_correlations()
    :ok
  end
end
