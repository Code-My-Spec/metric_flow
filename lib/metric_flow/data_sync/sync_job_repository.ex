defmodule MetricFlow.DataSync.SyncJobRepository do
  @moduledoc """
  Data access layer for SyncJob CRUD operations filtered by user_id.

  All operations are scoped via the Scope struct for multi-tenant isolation.
  Provides list_sync_jobs/1 for listing all jobs, get_sync_job/2 for single
  record retrieval, create_sync_job/3 for insertion, update_sync_job_status/3
  for status transitions with automatic timestamp management, and
  cancel_sync_job/2 for cancelling active jobs.

  Also provides unscoped create_sync_job/2 for background workers that create
  jobs across all users (e.g., the daily sync scheduler).
  """

  import Ecto.Query

  alias MetricFlow.DataSync.SyncJob
  alias MetricFlow.Integrations.Integration
  alias MetricFlow.Repo
  alias MetricFlow.Users.Scope

  # ---------------------------------------------------------------------------
  # list_sync_jobs/1
  # ---------------------------------------------------------------------------

  @doc """
  Returns all sync jobs for the scoped user, ordered by most recently created.

  Returns an empty list when no sync jobs exist for the user.
  """
  @spec list_sync_jobs(Scope.t()) :: list(SyncJob.t())
  def list_sync_jobs(%Scope{user: user}) do
    from(sj in SyncJob,
      where: sj.user_id == ^user.id,
      order_by: [desc: sj.inserted_at, desc: sj.id]
    )
    |> Repo.all()
  end

  # ---------------------------------------------------------------------------
  # get_sync_job/2
  # ---------------------------------------------------------------------------

  @doc """
  Retrieves a single sync job for the scoped user by ID.

  Returns {:ok, sync_job} when found or {:error, :not_found} when the sync job
  does not exist or belongs to a different user.
  """
  @spec get_sync_job(Scope.t(), integer()) :: {:ok, SyncJob.t()} | {:error, :not_found}
  def get_sync_job(%Scope{user: user}, id) do
    result =
      from(sj in SyncJob, where: sj.user_id == ^user.id and sj.id == ^id)
      |> Repo.one()

    case result do
      nil -> {:error, :not_found}
      sync_job -> {:ok, sync_job}
    end
  end

  # ---------------------------------------------------------------------------
  # create_sync_job/3
  # ---------------------------------------------------------------------------

  @doc """
  Creates a new sync job for the scoped user and integration.

  Merges user_id from the scope and integration_id into attrs before inserting.
  Defaults status to :pending when not provided.
  """
  @spec create_sync_job(Scope.t(), integer(), map()) ::
          {:ok, SyncJob.t()} | {:error, Ecto.Changeset.t()}
  def create_sync_job(%Scope{user: user}, integration_id, attrs) do
    attrs_with_ids =
      attrs
      |> Map.put(:user_id, user.id)
      |> Map.put(:integration_id, integration_id)
      |> Map.put_new(:status, :pending)

    %SyncJob{}
    |> SyncJob.changeset(attrs_with_ids)
    |> Repo.insert()
  end

  # ---------------------------------------------------------------------------
  # create_sync_job/2 (unscoped, for background workers)
  # ---------------------------------------------------------------------------

  @doc """
  Creates a new sync job from an Integration struct without a user scope.

  Derives user_id, integration_id, and provider directly from the Integration
  struct. Defaults status to :pending. Used by background workers (e.g.,
  Scheduler) that operate across all users and have no scope context.
  """
  @spec create_sync_job(Integration.t(), map()) ::
          {:ok, SyncJob.t()} | {:error, Ecto.Changeset.t()}
  def create_sync_job(%Integration{} = integration, attrs) do
    attrs_with_ids =
      attrs
      |> Map.put(:user_id, integration.user_id)
      |> Map.put(:integration_id, integration.id)
      |> Map.put(:provider, integration.provider)
      |> Map.put_new(:status, :pending)

    %SyncJob{}
    |> SyncJob.changeset(attrs_with_ids)
    |> Repo.insert()
  end

  # ---------------------------------------------------------------------------
  # update_sync_job_status/3
  # ---------------------------------------------------------------------------

  @doc """
  Updates the status of an existing sync job and sets appropriate timestamps.

  Sets started_at when transitioning to :running. Sets completed_at when
  transitioning to :completed, :failed, or :cancelled. Returns
  {:error, :not_found} when the sync job does not exist for the scoped user.
  """
  @spec update_sync_job_status(Scope.t(), integer(), atom()) ::
          {:ok, SyncJob.t()} | {:error, :not_found}
  def update_sync_job_status(%Scope{} = scope, id, new_status) do
    with {:ok, sync_job} <- get_sync_job(scope, id) do
      now = DateTime.utc_now()

      attrs =
        %{status: new_status}
        |> maybe_put_started_at(new_status, now)
        |> maybe_put_completed_at(new_status, now)

      sync_job
      |> SyncJob.changeset(attrs)
      |> Repo.update()
    end
  end

  # ---------------------------------------------------------------------------
  # cancel_sync_job/2
  # ---------------------------------------------------------------------------

  @doc """
  Cancels a pending or running sync job by setting status to :cancelled.

  Returns {:error, :not_found} when the sync job does not exist for the scoped
  user. Returns {:error, :invalid_status} when the sync job is already
  completed, failed, or cancelled.
  """
  @spec cancel_sync_job(Scope.t(), integer()) ::
          {:ok, SyncJob.t()} | {:error, :not_found} | {:error, :invalid_status}
  def cancel_sync_job(%Scope{} = scope, id) do
    with {:ok, sync_job} <- get_sync_job(scope, id),
         :ok <- validate_cancellable(sync_job) do
      now = DateTime.utc_now()

      attrs = %{status: :cancelled, completed_at: now}

      sync_job
      |> SyncJob.changeset(attrs)
      |> Repo.update()
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp maybe_put_started_at(attrs, :running, now), do: Map.put(attrs, :started_at, now)
  defp maybe_put_started_at(attrs, _status, _now), do: attrs

  defp maybe_put_completed_at(attrs, status, now)
       when status in [:completed, :failed, :cancelled],
       do: Map.put(attrs, :completed_at, now)

  defp maybe_put_completed_at(attrs, _status, _now), do: attrs

  defp validate_cancellable(%SyncJob{status: status})
       when status in [:pending, :running],
       do: :ok

  defp validate_cancellable(%SyncJob{}), do: {:error, :invalid_status}
end
