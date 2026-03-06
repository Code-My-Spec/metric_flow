defmodule MetricFlow.Correlations.CorrelationsRepository do
  @moduledoc """
  Data access layer for correlation CRUD operations.

  All queries are scoped by account_id via the Scope struct for multi-tenant
  isolation. Provides CRUD for CorrelationJob and CorrelationResult records
  with filtering and ordering.
  """

  import Ecto.Query

  alias MetricFlow.Correlations.CorrelationJob
  alias MetricFlow.Correlations.CorrelationResult
  alias MetricFlow.Repo
  alias MetricFlow.Users.Scope

  # ---------------------------------------------------------------------------
  # Correlation Results
  # ---------------------------------------------------------------------------

  @spec list_correlation_results(Scope.t(), keyword()) :: list(CorrelationResult.t())
  def list_correlation_results(%Scope{} = scope, opts \\ []) do
    account_id = get_account_id(scope)

    CorrelationResult
    |> where(account_id: ^account_id)
    |> filter_results(opts)
    |> order_by([r], fragment("ABS(?) DESC", r.coefficient))
    |> limit_offset(opts)
    |> Repo.all()
  end

  @spec get_correlation_result(Scope.t(), integer()) ::
          {:ok, CorrelationResult.t()} | {:error, :not_found}
  def get_correlation_result(%Scope{} = scope, id) do
    account_id = get_account_id(scope)

    case Repo.get_by(CorrelationResult, id: id, account_id: account_id) do
      nil -> {:error, :not_found}
      result -> {:ok, result}
    end
  end

  @spec create_correlation_result(Scope.t(), map()) ::
          {:ok, CorrelationResult.t()} | {:error, Ecto.Changeset.t()}
  def create_correlation_result(%Scope{} = scope, attrs) do
    account_id = get_account_id(scope)

    %CorrelationResult{}
    |> CorrelationResult.changeset(Map.put(attrs, :account_id, account_id))
    |> Repo.insert()
  end

  # ---------------------------------------------------------------------------
  # Correlation Jobs
  # ---------------------------------------------------------------------------

  @spec list_correlation_jobs(Scope.t()) :: list(CorrelationJob.t())
  def list_correlation_jobs(%Scope{} = scope) do
    account_id = get_account_id(scope)

    CorrelationJob
    |> where(account_id: ^account_id)
    |> order_by(desc: :inserted_at)
    |> Repo.all()
  end

  @spec get_correlation_job(Scope.t(), integer()) ::
          {:ok, CorrelationJob.t()} | {:error, :not_found}
  def get_correlation_job(%Scope{} = scope, id) do
    account_id = get_account_id(scope)

    case Repo.get_by(CorrelationJob, id: id, account_id: account_id) do
      nil -> {:error, :not_found}
      job -> {:ok, job}
    end
  end

  @spec create_correlation_job(Scope.t(), map()) ::
          {:ok, CorrelationJob.t()} | {:error, Ecto.Changeset.t()}
  def create_correlation_job(%Scope{} = scope, attrs) do
    account_id = get_account_id(scope)

    %CorrelationJob{}
    |> CorrelationJob.changeset(Map.put(attrs, :account_id, account_id))
    |> Repo.insert()
  end

  @spec update_correlation_job(Scope.t(), CorrelationJob.t(), map()) ::
          {:ok, CorrelationJob.t()} | {:error, Ecto.Changeset.t()}
  def update_correlation_job(%Scope{}, %CorrelationJob{} = job, attrs) do
    job
    |> CorrelationJob.changeset(attrs)
    |> Repo.update()
  end

  @spec get_latest_completed_job(Scope.t()) :: CorrelationJob.t() | nil
  def get_latest_completed_job(%Scope{} = scope) do
    account_id = get_account_id(scope)

    CorrelationJob
    |> where(account_id: ^account_id, status: :completed)
    |> order_by(desc: :completed_at)
    |> limit(1)
    |> Repo.one()
  end

  @spec has_running_job?(Scope.t()) :: boolean()
  def has_running_job?(%Scope{} = scope) do
    account_id = get_account_id(scope)

    CorrelationJob
    |> where(account_id: ^account_id)
    |> where([j], j.status in [:pending, :running])
    |> Repo.exists?()
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp get_account_id(%Scope{} = scope) do
    MetricFlow.Accounts.get_personal_account_id(scope)
  end

  defp filter_results(query, opts) do
    query
    |> maybe_filter_goal(Keyword.get(opts, :goal_metric_name))
    |> maybe_filter_min_coefficient(Keyword.get(opts, :min_coefficient))
  end

  defp maybe_filter_goal(query, nil), do: query

  defp maybe_filter_goal(query, goal_metric_name) do
    where(query, goal_metric_name: ^goal_metric_name)
  end

  defp maybe_filter_min_coefficient(query, nil), do: query

  defp maybe_filter_min_coefficient(query, min) do
    where(query, [r], fragment("ABS(?)", r.coefficient) >= ^min)
  end

  defp limit_offset(query, opts) do
    query
    |> maybe_limit(Keyword.get(opts, :limit))
    |> maybe_offset(Keyword.get(opts, :offset))
  end

  defp maybe_limit(query, nil), do: query
  defp maybe_limit(query, lim), do: limit(query, ^lim)

  defp maybe_offset(query, nil), do: query
  defp maybe_offset(query, off), do: offset(query, ^off)
end
