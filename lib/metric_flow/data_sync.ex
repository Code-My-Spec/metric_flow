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
  defdelegate get_last_successful_sync_at(scope, provider), to: SyncHistoryRepository

  # ---------------------------------------------------------------------------
  # sync_integration/2
  # ---------------------------------------------------------------------------

  @doc """
  Triggers a manual sync for a specific integration.

  Creates a SyncJob record with status `:pending` and enqueues a `SyncWorker`
  Oban job with the integration_id, user_id, and sync_job_id.

  Connectivity (expired token, no refresh token available) is not checked
  here. SyncWorker's own token-refresh step already fails the job with a
  clear, persisted error in that case -- checking here too meant a
  disconnected integration got no SyncJob, no SyncHistory row, and no
  visible indication it was skipped at all, for the manual trigger and the
  daily cron alike.

  Returns `{:ok, sync_job}` on success.
  Returns `{:error, :not_found}` when the integration does not exist for the
  scoped user and provider.
  """
  @spec sync_integration(Scope.t(), atom()) ::
          {:ok, SyncJob.t()} | {:error, :not_found}
  def sync_integration(%Scope{user: user} = scope, provider, opts \\ []) do
    with {:ok, integration} <- Integrations.get_integration(scope, provider),
         {:ok, sync_job} <-
           SyncJobRepository.create_sync_job(scope, integration.id, %{provider: provider}),
         {:ok, _oban_job} <-
           Oban.insert(
             SyncWorker.new(
               %{integration_id: integration.id, user_id: user.id, sync_job_id: sync_job.id}
               |> maybe_put_breakdown(opts)
               |> maybe_put_test_http_plug(provider)
             )
           ) do
      {:ok, sync_job}
    end
  end

  defp maybe_put_breakdown(args, opts) do
    case Keyword.get(opts, :breakdown) do
      nil -> args
      breakdown -> Map.put(args, :breakdown, to_string(breakdown))
    end
  end

  # A LiveView click can't pass a function through render_click/1, so specs
  # that need to drive a real sync register a plug by provider beforehand
  # (MetricFlowTest.PlugStore.put_provider_plug/2) instead of it arriving
  # through job args. Resolved dynamically, the same way SyncWorker resolves
  # its own test plugs, so this module still compiles outside :test.
  defp maybe_put_test_http_plug(args, provider) do
    plug_store = Module.concat([MetricFlowTest, PlugStore])

    if Code.ensure_loaded?(plug_store) do
      case :erlang.apply(plug_store, :get_provider_plug, [provider]) do
        {:ok, plug} ->
          # Oban.insert/1 persists args to Postgres via Jason, unlike
          # Oban.Testing.perform_job/3's own round-trip (native JSON module,
          # what PlugStore's JSON.Encoder targets) -- Jason has no Function
          # encoder, so the key is resolved here rather than the raw plug.
          key = :erlang.apply(plug_store, :store, [plug])
          Map.put(args, :http_plug, key)

        :error ->
          args
      end
    else
      args
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
