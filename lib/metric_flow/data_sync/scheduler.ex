defmodule MetricFlow.DataSync.Scheduler do
  @moduledoc """
  Oban scheduled job that runs daily to enqueue sync jobs for all active
  integrations.

  Triggered at 02:00 UTC by Oban.Plugins.Cron. Queries all integrations
  across all users, creates a SyncJob record with status :pending for each,
  and enqueues a SyncWorker job. Connectivity (expired token, no refresh
  token) is not checked here -- it used to be, which meant a disconnected
  integration was silently excluded from every cron run forever, with no
  SyncJob, no SyncHistory row, and no indication to the user. SyncWorker's
  own token-refresh step already fails such a job with a clear, persisted
  error, so every active integration is now scheduled and left to succeed
  or fail visibly there instead.

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

  Queries all integrations system-wide, creates a SyncJob record with status
  :pending for each, and enqueues a SyncWorker Oban job. An integration that
  turns out to be disconnected (expired with no refresh token) still gets a
  SyncJob and is still enqueued -- SyncWorker records that as a proper
  failure with a clear message, rather than the integration being excluded
  here with no record at all.

  Returns {:ok, count} with the number of jobs successfully scheduled.
  """
  @spec schedule_daily_syncs() :: {:ok, integer()}
  def schedule_daily_syncs do
    integrations = Integrations.list_all_active_integrations()

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

  defp schedule_integration(%Integration{} = integration) do
    with {:ok, sync_job} <- SyncJobRepository.create_sync_job(integration, %{}),
         {:ok, _oban_job} <-
           Oban.insert(
             SyncWorker.new(%{
               integration_id: integration.id,
               user_id: integration.user_id,
               sync_job_id: sync_job.id
             })
           ) do
      :ok
    end
  end
end
