defmodule MetricFlow.Correlations.CorrelationWorker do
  @moduledoc """
  Oban worker that executes correlation calculations for an account.

  Receives `job_id` and `user_id` in Oban job args. Updates the CorrelationJob
  status to :running, queries metric time series from MetricFlow.Metrics,
  computes Pearson correlations with TLCC across 0–30 day lags using the Math
  module, persists CorrelationResult records, and updates the job status to
  :completed or :failed. Uses Task.async_stream for parallel pair-wise
  computation.
  """

  use Oban.Worker,
    queue: :correlations,
    max_attempts: 3,
    unique: [
      fields: [:args],
      keys: [:job_id],
      period: 3_600,
      states: [:available, :scheduled, :executing]
    ]

  require Logger

  alias MetricFlow.Correlations.CorrelationsRepository
  alias MetricFlow.Correlations.Math
  alias MetricFlow.Metrics
  alias MetricFlow.Users.Scope
  alias MetricFlow.Users.User

  @impl Oban.Worker
  @spec perform(Oban.Job.t()) :: :ok | {:error, term()}
  def perform(%Oban.Job{args: args}) do
    job_id = Map.get(args, "job_id")
    user_id = Map.get(args, "user_id")
    account_id = Map.get(args, "account_id")
    scope = build_scope(user_id, account_id)

    Logger.info("CorrelationWorker starting job_id=#{job_id} user_id=#{user_id}")

    with {:ok, correlation_job} <- CorrelationsRepository.get_correlation_job(scope, job_id),
         {:ok, running_job} <- mark_running(scope, correlation_job) do
      execute(scope, running_job)
    else
      {:error, :not_found} ->
        Logger.error("CorrelationWorker job not found job_id=#{job_id}")
        {:error, :not_found}

      {:error, reason} ->
        Logger.error(
          "CorrelationWorker failed to start job_id=#{job_id} reason=#{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  # ---------------------------------------------------------------------------
  # Private — orchestration
  # ---------------------------------------------------------------------------

  defp build_scope(user_id, account_id) do
    %User{id: user_id}
    |> Scope.for_user()
    |> Scope.put_account_id(account_id)
  end

  defp mark_running(scope, job) do
    CorrelationsRepository.update_correlation_job(scope, job, %{
      status: :running,
      started_at: DateTime.utc_now()
    })
  end

  defp execute(scope, job) do
    goal_metric_name = job.goal_metric_name
    date_range = date_range_for_window(scope, job.time_window)

    metric_names =
      Metrics.list_metric_names(scope)
      |> Enum.reject(&(&1 == goal_metric_name))

    goal_series =
      Metrics.query_time_series(scope, goal_metric_name, date_range: date_range)

    {results, data_window} = compute_correlations(scope, metric_names, goal_series, date_range)

    case persist_results(scope, job, results, goal_metric_name, data_window) do
      {:ok, updated_job} ->
        broadcast_job_update(scope, updated_job)
        advance_queue(scope, updated_job)
        :ok

      {:error, reason} ->
        handle_failure(scope, job, reason)
    end
  rescue
    e ->
      error_message = Exception.message(e)
      Logger.error("CorrelationWorker exception job_id=#{job.id} error=#{error_message}")
      handle_failure(scope, job, error_message)
      {:error, {:exception, error_message}}
  end

  defp compute_correlations(scope, metric_names, goal_series, date_range) do
    goal_values = Enum.map(goal_series, & &1)

    results =
      metric_names
      |> Task.async_stream(
        &compute_metric_correlation(scope, &1, goal_values, date_range),
        max_concurrency: System.schedulers_online(),
        timeout: 30_000,
        on_timeout: :kill_task
      )
      |> Enum.reduce([], fn
        {:ok, nil}, acc -> acc
        {:ok, result}, acc -> [result | acc]
        {:exit, _reason}, acc -> acc
      end)

    data_window = extract_data_window(goal_series)
    {results, data_window}
  end

  defp compute_metric_correlation(scope, metric_name, goal_values, date_range) do
    metric_series =
      Metrics.query_time_series(scope, metric_name, date_range: date_range)

    {metric_values, goal_aligned} = Math.extract_values(metric_series, goal_values)

    case Math.cross_correlate(metric_values, goal_aligned) do
      nil ->
        nil

      {optimal_lag, coefficient} ->
        %{
          metric_name: metric_name,
          coefficient: coefficient,
          optimal_lag: optimal_lag,
          data_points: length(metric_values),
          provider: detect_provider(scope, metric_name, date_range)
        }
    end
  end

  defp persist_results(scope, job, results, goal_metric_name, {window_start, window_end}) do
    now = DateTime.utc_now()

    Enum.each(results, fn result ->
      attrs =
        Map.merge(result, %{
          correlation_job_id: job.id,
          goal_metric_name: goal_metric_name,
          calculated_at: now
        })

      case CorrelationsRepository.create_correlation_result(scope, attrs) do
        {:ok, _} ->
          :ok

        {:error, reason} ->
          Logger.warning(
            "CorrelationWorker failed to persist result metric=#{result.metric_name} " <>
              "reason=#{inspect(reason)}"
          )
      end
    end)

    CorrelationsRepository.update_correlation_job(scope, job, %{
      status: :completed,
      completed_at: now,
      results_count: length(results),
      data_window_start: window_start,
      data_window_end: window_end,
      data_points: Enum.map(results, & &1.data_points) |> Enum.max(fn -> 0 end)
    })
  end

  defp persist_results(scope, job, _results, _goal_metric_name, nil) do
    CorrelationsRepository.update_correlation_job(scope, job, %{
      status: :completed,
      completed_at: DateTime.utc_now(),
      results_count: 0
    })
  end

  defp handle_failure(scope, job, reason) do
    error_message = if is_binary(reason), do: reason, else: inspect(reason)

    case CorrelationsRepository.update_correlation_job(scope, job, %{
           status: :failed,
           completed_at: DateTime.utc_now(),
           error_message: error_message
         }) do
      {:ok, updated_job} ->
        broadcast_job_update(scope, updated_job)
        advance_queue(scope, updated_job)

      _ ->
        :ok
    end

    {:error, reason}
  end

  # Starts the next queued goal (if any) once the current job finishes,
  # whether it completed or failed -- only one job runs per account at a
  # time, so a multi-goal submission enqueues the rest via
  # Correlations.run_correlations_for_multiple_goals/3 and this is what
  # actually works through them one by one.
  defp advance_queue(scope, %{account_id: account_id}) do
    case CorrelationsRepository.pop_next_queued_goal(account_id) do
      nil ->
        :ok

      {goal_metric_name, time_window} ->
        queued_scope = Scope.put_account_id(scope, account_id)
        job_attrs = %{goal_metric_name: goal_metric_name, time_window: time_window}

        case CorrelationsRepository.create_correlation_job(queued_scope, job_attrs) do
          {:ok, new_job} ->
            %{job_id: new_job.id, user_id: scope.user.id, account_id: account_id}
            |> __MODULE__.new()
            |> Oban.insert()

            :ok

          {:error, _changeset} ->
            :ok
        end
    end
  end

  # ---------------------------------------------------------------------------
  # Private — helpers
  # ---------------------------------------------------------------------------

  # Anchored to the account's actual latest metric date, not wall-clock
  # "today" -- seeded or historical data commonly falls outside a fixed
  # recent window. :all_time returns nil, which Metrics.query_time_series
  # treats as no date constraint at all (not the same as the key being
  # absent, which would default to the last 30 days).
  defp date_range_for_window(scope, :days_30) do
    end_date = Metrics.get_latest_metric_date(scope) || Date.utc_today()
    {Date.add(end_date, -30), end_date}
  end

  defp date_range_for_window(scope, :all_time) do
    _ = scope
    nil
  end

  defp date_range_for_window(scope, _days_90_or_nil) do
    end_date = Metrics.get_latest_metric_date(scope) || Date.utc_today()
    {Date.add(end_date, -90), end_date}
  end

  defp extract_data_window([]), do: nil

  defp extract_data_window(series) do
    dates = Enum.map(series, & &1.date)
    {Enum.min(dates, Date), Enum.max(dates, Date)}
  end

  # Real metric rows store provider as its own column, not a name prefix --
  # look it up directly rather than guessing from metric_name.
  defp detect_provider(scope, metric_name, date_range) do
    case Metrics.list_providers_for_metric(scope, metric_name, date_range: date_range) do
      [provider | _] -> provider
      [] -> nil
    end
  end

  defp broadcast_job_update(%Scope{user: user}, job) do
    Phoenix.PubSub.broadcast(
      MetricFlow.PubSub,
      "user:#{user.id}:correlations",
      {:correlation_job_updated, job}
    )
  end
end
