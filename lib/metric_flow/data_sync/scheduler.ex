defmodule MetricFlow.DataSync.Scheduler do
  @moduledoc """
  Oban scheduled job that runs daily to enqueue sync jobs for all active
  integrations.

  Triggered at 02:00 UTC by Oban.Plugins.Cron. Queries all integrations
  across all users, filters to those with valid refresh tokens, creates
  SyncJob records with status :pending, and enqueues SyncWorker jobs.

  Never retries (max_attempts: 1). If the scheduler itself fails, the next
  cron invocation picks it up. Retrying risks double-scheduling sync jobs for
  integrations that were already enqueued before the failure.
  """

  use Oban.Worker,
    queue: :sync,
    max_attempts: 1

  alias MetricFlow.DataSync.SyncJobRepository
  alias MetricFlow.DataSync.SyncWorker
  alias MetricFlow.Integrations
  alias MetricFlow.Integrations.Integration

  @impl Oban.Worker
  @spec perform(Oban.Job.t()) :: :ok | {:error, term()}
  def perform(%Oban.Job{}) do
    {:ok, _count} = schedule_daily_syncs()
    :ok
  end

  @doc """
  Schedules sync jobs for all active integrations across all users.

  Queries all integrations system-wide, filters to those with valid refresh
  tokens (expired integrations with refresh tokens are included since
  SyncWorker handles token refresh), creates a SyncJob record with status
  :pending for each qualifying integration, and enqueues a SyncWorker Oban
  job.

  Returns {:ok, count} with the number of jobs successfully scheduled.
  """
  @spec schedule_daily_syncs() :: {:ok, integer()}
  def schedule_daily_syncs do
    integrations =
      Integrations.list_all_active_integrations()
      |> Enum.filter(&schedulable?/1)

    count =
      Enum.reduce(integrations, 0, fn integration, acc ->
        case schedule_integration(integration) do
          :ok -> acc + 1
          _ -> acc
        end
      end)

    {:ok, count}
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp schedulable?(%Integration{} = integration) do
    Integration.has_refresh_token?(integration)
  end

  defp schedule_integration(%Integration{} = integration) do
    with {:ok, _sync_job} <- SyncJobRepository.create_sync_job(integration, %{}),
         {:ok, _oban_job} <-
           Oban.insert(
             SyncWorker.new(%{
               integration_id: integration.id,
               user_id: integration.user_id
             })
           ) do
      :ok
    end
  end
end
