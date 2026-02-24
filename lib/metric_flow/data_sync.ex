defmodule MetricFlow.DataSync do
  @moduledoc """
  Public API boundary for the DataSync bounded context.

  Orchestrates automated daily syncs and manual data pulls from external
  platforms (Google Ads, Google Analytics, Facebook Ads, QuickBooks),
  persisting unified metrics through the Metrics context.

  All public functions accept a `%Scope{}` as the first parameter for
  multi-tenant isolation. The exception is `schedule_daily_syncs/0`, which
  operates system-wide and requires no scope.
  """

  use Boundary,
    deps: [MetricFlow, MetricFlow.Integrations, MetricFlow.Metrics, MetricFlow.Users],
    exports: [DataProviders.Behaviour]

  alias MetricFlow.DataSync.Scheduler
  alias MetricFlow.DataSync.SyncHistoryRepository
  alias MetricFlow.DataSync.SyncJobRepository
  alias MetricFlow.DataSync.SyncWorker
  alias MetricFlow.Integrations
  alias MetricFlow.Integrations.Integration
  alias MetricFlow.Users.Scope

  # ---------------------------------------------------------------------------
  # Delegated functions
  # ---------------------------------------------------------------------------

  @doc """
  Retrieves a specific sync job for the scoped user.

  Returns `{:ok, sync_job}` when found or `{:error, :not_found}` when the sync
  job does not exist or belongs to a different user.
  """
  @spec get_sync_job(Scope.t(), integer()) :: {:ok, SyncJob.t()} | {:error, :not_found}
  defdelegate get_sync_job(scope, id), to: SyncJobRepository

  @doc """
  Lists all sync jobs for the scoped user, ordered by most recently created.

  Returns an empty list when no sync jobs exist for the user.
  """
  @spec list_sync_jobs(Scope.t()) :: list(SyncJob.t())
  defdelegate list_sync_jobs(scope), to: SyncJobRepository

  @doc """
  Retrieves a specific sync history record for the scoped user.

  Returns `{:ok, sync_history}` when found or `{:error, :not_found}` when the
  record does not exist or belongs to a different user.
  """
  @spec get_sync_history(Scope.t(), integer()) :: {:ok, SyncHistory.t()} | {:error, :not_found}
  defdelegate get_sync_history(scope, id), to: SyncHistoryRepository

  @doc """
  Lists sync history for the scoped user with optional filtering and pagination.

  Supports the following options:
  - `:provider` — filter to a specific provider atom
  - `:limit` — maximum number of records to return
  - `:offset` — number of records to skip before returning results

  Records are ordered by most recently completed first.
  Returns an empty list when no sync history exists for the user.
  """
  @spec list_sync_history(Scope.t(), keyword()) :: list(SyncHistory.t())
  defdelegate list_sync_history(scope, opts \\ []), to: SyncHistoryRepository

  # ---------------------------------------------------------------------------
  # sync_integration/2
  # ---------------------------------------------------------------------------

  @doc """
  Triggers a manual sync for a specific integration.

  Verifies the integration exists and is connected (not expired without a
  refresh token), creates a SyncJob record with status `:pending`, and enqueues
  a `SyncWorker` Oban job with the integration_id, user_id, and sync_job_id.

  Returns `{:ok, sync_job}` on success.
  Returns `{:error, :not_found}` when the integration does not exist for the
  scoped user and provider.
  Returns `{:error, :not_connected}` when the integration exists but its token
  is expired and no refresh token is available.
  """
  @spec sync_integration(Scope.t(), atom()) ::
          {:ok, SyncJob.t()} | {:error, :not_found} | {:error, :not_connected}
  def sync_integration(%Scope{user: user} = scope, provider) do
    with {:ok, integration} <- Integrations.get_integration(scope, provider),
         :ok <- check_connected(integration),
         {:ok, sync_job} <-
           SyncJobRepository.create_sync_job(scope, integration.id, %{provider: provider}),
         {:ok, _oban_job} <-
           Oban.insert(
             SyncWorker.new(%{
               integration_id: integration.id,
               user_id: user.id,
               sync_job_id: sync_job.id
             })
           ) do
      {:ok, sync_job}
    end
  end

  # ---------------------------------------------------------------------------
  # schedule_daily_syncs/0
  # ---------------------------------------------------------------------------

  @doc """
  Schedules sync jobs for all active integrations across all users.

  Queries all integrations system-wide, filters to those with valid tokens or
  refresh tokens, creates SyncJob records with status `:pending`, and enqueues
  SyncWorker Oban jobs.

  Returns `{:ok, count}` with the number of jobs successfully scheduled.
  """
  @spec schedule_daily_syncs() :: {:ok, integer()}
  defdelegate schedule_daily_syncs(), to: Scheduler

  # ---------------------------------------------------------------------------
  # cancel_sync_job/2
  # ---------------------------------------------------------------------------

  @doc """
  Cancels a pending or running sync job.

  Retrieves the sync job for the scoped user, verifies it is cancellable
  (status must be `:pending` or `:running`), and updates the status to
  `:cancelled`. When the job is `:pending`, also attempts to cancel the
  corresponding Oban job.

  Returns `{:ok, sync_job}` with the updated sync job on success.
  Returns `{:error, :not_found}` when the sync job does not exist for the
  scoped user.
  Returns `{:error, :invalid_status}` when the sync job status is `:completed`,
  `:failed`, or `:cancelled`.
  """
  @spec cancel_sync_job(Scope.t(), integer()) ::
          {:ok, SyncJob.t()} | {:error, :not_found} | {:error, :invalid_status}
  def cancel_sync_job(%Scope{} = scope, id) do
    with {:ok, sync_job} <- SyncJobRepository.get_sync_job(scope, id),
         :ok <- validate_cancellable(sync_job),
         {:ok, cancelled_job} <- SyncJobRepository.cancel_sync_job(scope, id) do
      maybe_cancel_oban_job(sync_job)
      {:ok, cancelled_job}
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp check_connected(%Integration{} = integration) do
    if Integration.expired?(integration) and not Integration.has_refresh_token?(integration) do
      {:error, :not_connected}
    else
      :ok
    end
  end

  defp validate_cancellable(%{status: status}) when status in [:pending, :running], do: :ok
  defp validate_cancellable(_sync_job), do: {:error, :invalid_status}

  defp maybe_cancel_oban_job(%{status: :pending, id: sync_job_id}) do
    import Ecto.Query

    MetricFlow.Repo.all(
      from(j in Oban.Job,
        where: j.worker == "MetricFlow.DataSync.SyncWorker",
        where: fragment("?->>'sync_job_id' = ?", j.args, ^to_string(sync_job_id)),
        where: j.state in ["available", "scheduled"]
      )
    )
    |> Enum.each(&Oban.cancel_job(&1.id))
  end

  defp maybe_cancel_oban_job(_sync_job), do: :ok
end
