defmodule MetricFlow.DataSync.SyncHistoryRepository do
  @moduledoc """
  Data access layer for SyncHistory read operations filtered by user_id.

  All operations are scoped via the Scope struct for multi-tenant isolation.
  Provides list_sync_history/2 with filter options (provider, limit, offset),
  get_sync_history/2, and create_sync_history/2 functions. Queries are ordered
  by most recently completed first.
  """

  import Ecto.Query

  alias MetricFlow.DataSync.SyncHistory
  alias MetricFlow.Repo
  alias MetricFlow.Users.Scope

  @valid_providers [:google_analytics, :google_ads, :facebook_ads, :quickbooks]

  # ---------------------------------------------------------------------------
  # list_sync_history/2
  # ---------------------------------------------------------------------------

  @doc """
  Returns sync history records for the scoped user with optional filtering and
  pagination, ordered by most recently completed.

  Supports filtering by provider and pagination via limit and offset options.
  Invalid provider values return an empty list. Returns an empty list when no
  records exist for the scoped user.
  """
  @spec list_sync_history(Scope.t(), keyword()) :: list(SyncHistory.t())
  def list_sync_history(%Scope{user: user}, opts \\ []) do
    case validate_provider_opt(opts) do
      :invalid ->
        []

      :ok ->
        from(sh in SyncHistory, where: sh.user_id == ^user.id)
        |> apply_provider_filter(opts)
        |> order_by([sh], desc: sh.completed_at, desc: sh.id)
        |> apply_limit(opts)
        |> apply_offset(opts)
        |> Repo.all()
    end
  end

  # ---------------------------------------------------------------------------
  # get_sync_history/2
  # ---------------------------------------------------------------------------

  @doc """
  Retrieves a single sync history record for the scoped user by ID.

  Returns {:ok, sync_history} when found or {:error, :not_found} when the
  record does not exist or belongs to a different user.
  """
  @spec get_sync_history(Scope.t(), integer()) :: {:ok, SyncHistory.t()} | {:error, :not_found}
  def get_sync_history(%Scope{user: user}, id) do
    result =
      from(sh in SyncHistory,
        where: sh.user_id == ^user.id and sh.id == ^id
      )
      |> Repo.one()

    case result do
      nil -> {:error, :not_found}
      sync_history -> {:ok, sync_history}
    end
  end

  # ---------------------------------------------------------------------------
  # create_sync_history/2
  # ---------------------------------------------------------------------------

  @doc """
  Creates a new sync history record for the scoped user.

  Merges user_id from the scope into attrs before inserting. The scope's
  user_id always takes precedence over any user_id in the attrs map. Validates
  provider, status, required fields, and that referenced associations exist.
  """
  @spec create_sync_history(Scope.t(), map()) ::
          {:ok, SyncHistory.t()} | {:error, Ecto.Changeset.t()}
  def create_sync_history(%Scope{user: user}, attrs) do
    attrs_with_user = Map.put(attrs, :user_id, user.id)

    %SyncHistory{}
    |> SyncHistory.changeset(attrs_with_user)
    |> Repo.insert()
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp validate_provider_opt(opts) do
    case Keyword.get(opts, :provider) do
      nil -> :ok
      provider when provider in @valid_providers -> :ok
      _invalid -> :invalid
    end
  end

  defp apply_provider_filter(query, opts) do
    case Keyword.get(opts, :provider) do
      nil -> query
      provider -> where(query, [sh], sh.provider == ^provider)
    end
  end

  defp apply_limit(query, opts) do
    case Keyword.get(opts, :limit) do
      nil -> query
      limit -> limit(query, ^limit)
    end
  end

  defp apply_offset(query, opts) do
    case Keyword.get(opts, :offset) do
      nil -> query
      offset -> offset(query, ^offset)
    end
  end
end
