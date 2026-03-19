defmodule MetricFlow.Correlations do
  @moduledoc """
  Public API boundary for the Correlations bounded context.

  Computes Pearson correlation coefficients with time-lagged cross-correlation
  (TLCC) between marketing/financial metrics and user-selected goal metrics.
  Orchestrates background correlation jobs via Oban, stores results, and
  exposes query functions for the CorrelationLive views.

  All public functions accept a `%Scope{}` as the first parameter for
  multi-tenant isolation.
  """

  use Boundary,
    deps: [MetricFlow, MetricFlow.Metrics, MetricFlow.Integrations],
    exports: [CorrelationJob, CorrelationResult]

  alias MetricFlow.Correlations.CorrelationJob
  alias MetricFlow.Correlations.CorrelationsRepository
  alias MetricFlow.Correlations.CorrelationWorker
  alias MetricFlow.Integrations
  alias MetricFlow.Metrics
  alias MetricFlow.Users.Scope
  alias MetricFlow.Users.User

  # ---------------------------------------------------------------------------
  # Delegated repository functions
  # ---------------------------------------------------------------------------

  defdelegate list_correlation_results(scope, opts \\ []), to: CorrelationsRepository
  defdelegate get_correlation_result(scope, id), to: CorrelationsRepository
  defdelegate get_correlation_job(scope, id), to: CorrelationsRepository
  defdelegate list_correlation_jobs(scope), to: CorrelationsRepository

  # ---------------------------------------------------------------------------
  # Correlation orchestration
  # ---------------------------------------------------------------------------

  @doc """
  Triggers correlation calculation for a scoped user's metrics.

  Creates a CorrelationJob and enqueues the CorrelationWorker. Returns
  `:already_running` when a pending or running job exists, and
  `:insufficient_data` when fewer than 30 days of metric data are available.
  """
  @spec run_correlations(Scope.t(), map()) ::
          {:ok, CorrelationJob.t()} | {:error, :insufficient_data} | {:error, :already_running}
  def run_correlations(%Scope{} = scope, attrs) do
    with :ok <- check_no_running_job(scope),
         :ok <- check_sufficient_data(scope) do
      create_and_enqueue(scope, attrs)
    end
  end

  @doc """
  Schedules correlation recalculation for all users with sufficient data.

  Called by Oban cron after daily data sync completes. Skips users with a
  correlation job completed within the last 24 hours.
  """
  @spec schedule_daily_correlations() :: {:ok, integer()}
  def schedule_daily_correlations do
    user_ids =
      Integrations.list_all_active_integrations()
      |> Enum.map(& &1.user_id)
      |> Enum.uniq()

    count =
      user_ids
      |> Enum.map(&Scope.for_user(%User{id: &1}))
      |> Enum.filter(&schedulable?/1)
      |> Enum.count(&schedule_user_correlations/1)

    {:ok, count}
  end

  @doc """
  Returns a summary of the most recent correlation results for the scoped
  user, suitable for display on the correlations page.
  """
  @spec get_latest_correlation_summary(Scope.t()) :: map()
  def get_latest_correlation_summary(%Scope{} = scope) do
    case CorrelationsRepository.get_latest_completed_job(scope) do
      nil ->
        %{
          results: [],
          goal_metric_name: nil,
          last_calculated_at: nil,
          data_window: nil,
          data_points_count: nil,
          no_data: true
        }

      %CorrelationJob{} = job ->
        results = CorrelationsRepository.list_correlation_results(scope, correlation_job_id: job.id)

        %{
          results: results,
          goal_metric_name: job.goal_metric_name,
          last_calculated_at: job.completed_at,
          data_window: {job.data_window_start, job.data_window_end},
          data_points_count: job.data_points,
          no_data: false
        }
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp schedule_user_correlations(%Scope{} = scope) do
    goal = determine_goal_metric(scope)

    match?({:ok, _}, create_and_enqueue(scope, %{goal_metric_name: goal}))
  end

  defp schedulable?(%Scope{} = scope) do
    has_sufficient_metrics?(scope) and not has_recent_completed_job?(scope)
  end

  defp has_sufficient_metrics?(%Scope{} = scope) do
    length(Metrics.list_metric_names(scope)) >= 2
  end

  defp has_recent_completed_job?(%Scope{} = scope) do
    case CorrelationsRepository.get_latest_completed_job(scope) do
      nil ->
        false

      %CorrelationJob{completed_at: completed_at} ->
        cutoff = DateTime.add(DateTime.utc_now(), -24 * 3600, :second)
        DateTime.compare(completed_at, cutoff) == :gt
    end
  end

  defp determine_goal_metric(%Scope{} = scope) do
    case CorrelationsRepository.get_latest_completed_job(scope) do
      %CorrelationJob{goal_metric_name: name} when is_binary(name) ->
        name

      _ ->
        case Metrics.list_metric_names(scope) do
          [first | _] -> first
          [] -> "revenue"
        end
    end
  end

  defp check_no_running_job(%Scope{} = scope) do
    if CorrelationsRepository.has_running_job?(scope) do
      {:error, :already_running}
    else
      :ok
    end
  end

  defp check_sufficient_data(%Scope{} = scope) do
    metric_names = Metrics.list_metric_names(scope)

    if length(metric_names) >= 2 do
      :ok
    else
      {:error, :insufficient_data}
    end
  end

  defp create_and_enqueue(%Scope{user: user} = scope, attrs) do
    goal_metric_name = Map.get(attrs, :goal_metric_name) || Map.get(attrs, "goal_metric_name")

    case CorrelationsRepository.create_correlation_job(scope, %{goal_metric_name: goal_metric_name}) do
      {:ok, job} ->
        %{job_id: job.id, user_id: user.id}
        |> CorrelationWorker.new()
        |> Oban.insert()

        {:ok, job}

      {:error, changeset} ->
        {:error, changeset}
    end
  end
end
