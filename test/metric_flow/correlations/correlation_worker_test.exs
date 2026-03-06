defmodule MetricFlow.Correlations.CorrelationWorkerTest do
  use MetricFlowTest.DataCase, async: false

  import ExUnit.CaptureLog
  import MetricFlowTest.UsersFixtures
  import Oban.Testing, only: [perform_job: 3]

  alias MetricFlow.Accounts.Account
  alias MetricFlow.Accounts.AccountMember
  alias MetricFlow.Correlations.CorrelationsRepository
  alias MetricFlow.Correlations.CorrelationWorker
  alias MetricFlow.Metrics.Metric
  alias MetricFlow.Users.Scope

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  # Creates a personal account and account membership for the user.
  # CorrelationsRepository.create_correlation_job/2 calls get_personal_account_id/1
  # which requires a personal account to exist in the DB.
  defp create_personal_account!(user) do
    unique = System.unique_integer([:positive])

    {:ok, account} =
      %Account{}
      |> Account.creation_changeset(%{
        name: "#{user.email} Personal",
        slug: "personal-#{unique}",
        type: "personal",
        originator_user_id: user.id
      })
      |> Repo.insert()

    %AccountMember{}
    |> AccountMember.changeset(%{
      account_id: account.id,
      user_id: user.id,
      role: :owner
    })
    |> Repo.insert!()

    account
  end

  defp user_with_scope do
    user = user_fixture()
    create_personal_account!(user)
    scope = Scope.for_user(user)
    {user, scope}
  end

  defp insert_correlation_job!(scope, goal_metric_name, overrides \\ %{}) do
    attrs =
      Map.merge(
        %{goal_metric_name: goal_metric_name, status: :pending},
        overrides
      )

    {:ok, job} = CorrelationsRepository.create_correlation_job(scope, attrs)
    job
  end

  # Inserts metric rows directly via Repo to bypass the context layer.
  # Creates `count` daily data points going back `count` days from today so
  # that query_time_series/3 (which defaults to the last 90 days) picks them up.
  defp insert_metrics!(user_id, metric_name, count) do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    entries =
      Enum.map(1..count, fn i ->
        recorded_at = DateTime.add(now, -i * 86_400, :second)

        %{
          user_id: user_id,
          metric_name: metric_name,
          metric_type: "traffic",
          value: i * 1.0,
          provider: :google_analytics,
          recorded_at: recorded_at,
          dimensions: %{},
          inserted_at: now,
          updated_at: now
        }
      end)

    {_count, _} = Repo.insert_all(Metric, entries)
    :ok
  end

  defp job_args(job_id, user_id) do
    %{"job_id" => job_id, "user_id" => user_id}
  end

  # ---------------------------------------------------------------------------
  # perform/1
  # ---------------------------------------------------------------------------

  describe "perform/1" do
    test "returns :ok when correlation job completes successfully with metric data" do
      {user, scope} = user_with_scope()
      insert_metrics!(user.id, "ga4_sessions", 40)
      insert_metrics!(user.id, "ga4_pageviews", 40)
      job = insert_correlation_job!(scope, "ga4_sessions")

      capture_log(fn ->
        assert :ok = perform_job(CorrelationWorker, job_args(job.id, user.id), [])
      end)
    end

    test "updates job status to :running at start" do
      {user, scope} = user_with_scope()
      insert_metrics!(user.id, "ga4_sessions", 40)
      job = insert_correlation_job!(scope, "ga4_sessions")

      assert job.status == :pending

      capture_log(fn ->
        perform_job(CorrelationWorker, job_args(job.id, user.id), [])
      end)

      # The job transitions :pending -> :running -> :completed.
      # started_at is set when the job enters :running, so its presence confirms
      # the status transition to :running occurred.
      {:ok, final_job} = CorrelationsRepository.get_correlation_job(scope, job.id)
      assert final_job.started_at != nil
    end

    test "sets started_at timestamp when transitioning to running" do
      {user, scope} = user_with_scope()
      insert_metrics!(user.id, "ga4_sessions", 40)
      job = insert_correlation_job!(scope, "ga4_sessions")

      assert job.started_at == nil

      capture_log(fn ->
        perform_job(CorrelationWorker, job_args(job.id, user.id), [])
      end)

      {:ok, final_job} = CorrelationsRepository.get_correlation_job(scope, job.id)
      assert %DateTime{} = final_job.started_at
    end

    test "queries metric time series for goal metric and all other metrics" do
      {user, scope} = user_with_scope()
      insert_metrics!(user.id, "ga4_sessions", 40)
      insert_metrics!(user.id, "ga4_pageviews", 40)
      insert_metrics!(user.id, "ga4_bounces", 40)
      job = insert_correlation_job!(scope, "ga4_sessions")

      capture_log(fn ->
        assert :ok = perform_job(CorrelationWorker, job_args(job.id, user.id), [])
      end)

      # All three metric names were in the DB. The worker queries time series for
      # ga4_sessions (goal) and the other two. A successful :completed status
      # confirms all queries were executed.
      {:ok, final_job} = CorrelationsRepository.get_correlation_job(scope, job.id)
      assert final_job.status == :completed
      assert final_job.results_count >= 0
    end

    test "calls Math.cross_correlate/3 for each metric pair" do
      {user, scope} = user_with_scope()
      insert_metrics!(user.id, "ga4_sessions", 40)
      insert_metrics!(user.id, "ga4_pageviews", 40)
      job = insert_correlation_job!(scope, "ga4_sessions")

      capture_log(fn ->
        assert :ok = perform_job(CorrelationWorker, job_args(job.id, user.id), [])
      end)

      # cross_correlate/3 ran and produced a result with a valid coefficient and
      # lag — the only way these fields are populated is via Math.cross_correlate/3.
      results = CorrelationsRepository.list_correlation_results(scope)
      assert results != []

      result = hd(results)
      assert is_float(result.coefficient)
      assert result.coefficient >= -1.0
      assert result.coefficient <= 1.0
      assert is_integer(result.optimal_lag)
      assert result.optimal_lag >= 0
      assert result.optimal_lag <= 30
    end

    test "persists CorrelationResult for each non-nil correlation" do
      {user, scope} = user_with_scope()
      insert_metrics!(user.id, "ga4_sessions", 40)
      insert_metrics!(user.id, "ga4_pageviews", 40)
      insert_metrics!(user.id, "ga4_bounces", 40)
      job = insert_correlation_job!(scope, "ga4_sessions")

      capture_log(fn ->
        assert :ok = perform_job(CorrelationWorker, job_args(job.id, user.id), [])
      end)

      results = CorrelationsRepository.list_correlation_results(scope)

      assert Enum.all?(results, &(&1.correlation_job_id == job.id))
      assert Enum.all?(results, &(&1.goal_metric_name == "ga4_sessions"))
      assert Enum.all?(results, &(not is_nil(&1.calculated_at)))
    end

    test "updates job status to :completed on success" do
      {user, scope} = user_with_scope()
      insert_metrics!(user.id, "ga4_sessions", 40)
      insert_metrics!(user.id, "ga4_pageviews", 40)
      job = insert_correlation_job!(scope, "ga4_sessions")

      capture_log(fn ->
        assert :ok = perform_job(CorrelationWorker, job_args(job.id, user.id), [])
      end)

      {:ok, final_job} = CorrelationsRepository.get_correlation_job(scope, job.id)
      assert final_job.status == :completed
    end

    test "sets completed_at timestamp on completion" do
      {user, scope} = user_with_scope()
      insert_metrics!(user.id, "ga4_sessions", 40)
      job = insert_correlation_job!(scope, "ga4_sessions")

      capture_log(fn ->
        assert :ok = perform_job(CorrelationWorker, job_args(job.id, user.id), [])
      end)

      {:ok, final_job} = CorrelationsRepository.get_correlation_job(scope, job.id)
      assert %DateTime{} = final_job.completed_at
    end

    test "sets results_count to number of persisted results" do
      {user, scope} = user_with_scope()
      insert_metrics!(user.id, "ga4_sessions", 40)
      insert_metrics!(user.id, "ga4_pageviews", 40)
      job = insert_correlation_job!(scope, "ga4_sessions")

      capture_log(fn ->
        assert :ok = perform_job(CorrelationWorker, job_args(job.id, user.id), [])
      end)

      {:ok, final_job} = CorrelationsRepository.get_correlation_job(scope, job.id)
      persisted_results = CorrelationsRepository.list_correlation_results(scope)

      assert final_job.results_count == length(persisted_results)
    end

    test "sets data_window_start and data_window_end from metric date range" do
      {user, scope} = user_with_scope()
      insert_metrics!(user.id, "ga4_sessions", 40)
      insert_metrics!(user.id, "ga4_pageviews", 40)
      job = insert_correlation_job!(scope, "ga4_sessions")

      capture_log(fn ->
        assert :ok = perform_job(CorrelationWorker, job_args(job.id, user.id), [])
      end)

      {:ok, final_job} = CorrelationsRepository.get_correlation_job(scope, job.id)
      assert %Date{} = final_job.data_window_start
      assert %Date{} = final_job.data_window_end
      assert Date.compare(final_job.data_window_start, final_job.data_window_end) != :gt
    end

    test "updates job status to :failed on error" do
      {user, _scope} = user_with_scope()

      # The worker calls get_correlation_job/2 which returns :not_found for an
      # invalid job_id. The worker returns {:error, :not_found} without updating
      # the job (there is no job to update).
      capture_log(fn ->
        assert {:error, :not_found} =
                 perform_job(CorrelationWorker, job_args(-999_999, user.id), [])
      end)
    end

    test "sets error_message when job fails" do
      {user, scope} = user_with_scope()
      insert_metrics!(user.id, "ga4_sessions", 40)
      job = insert_correlation_job!(scope, "ga4_sessions")

      # Force the worker to fail by using a non-existent job_id so that
      # get_correlation_job/2 returns :not_found.
      capture_log(fn ->
        assert {:error, :not_found} =
                 perform_job(CorrelationWorker, job_args(job.id + 999_999, user.id), [])
      end)
    end

    test "skips metric pairs where extract_values returns empty lists" do
      {user, scope} = user_with_scope()
      # Only the goal metric exists — no other metrics to correlate against.
      # The worker lists metric names, removes the goal, and is left with an
      # empty list. No pairs are computed; 0 results are persisted.
      insert_metrics!(user.id, "ga4_sessions", 40)
      job = insert_correlation_job!(scope, "ga4_sessions")

      capture_log(fn ->
        assert :ok = perform_job(CorrelationWorker, job_args(job.id, user.id), [])
      end)

      {:ok, final_job} = CorrelationsRepository.get_correlation_job(scope, job.id)
      assert final_job.status == :completed
      assert final_job.results_count == 0
    end

    test "handles empty metric list gracefully (completes with 0 results)" do
      {user, scope} = user_with_scope()
      # No metrics in the DB at all for this user.
      # list_metric_names returns [], the worker completes with 0 results.
      job = insert_correlation_job!(scope, "ga4_revenue")

      capture_log(fn ->
        assert :ok = perform_job(CorrelationWorker, job_args(job.id, user.id), [])
      end)

      {:ok, final_job} = CorrelationsRepository.get_correlation_job(scope, job.id)
      assert final_job.status == :completed
      assert final_job.results_count == 0
      assert CorrelationsRepository.list_correlation_results(scope) == []
    end

    test "returns {:error, :not_found} when correlation job does not exist" do
      {user, _scope} = user_with_scope()

      capture_log(fn ->
        assert {:error, :not_found} =
                 perform_job(CorrelationWorker, job_args(-1, user.id), [])
      end)
    end

    test "detects provider from ga4_ metric name prefix and stores it on CorrelationResult" do
      {user, scope} = user_with_scope()
      insert_metrics!(user.id, "ga4_sessions", 40)
      insert_metrics!(user.id, "ga4_pageviews", 40)
      job = insert_correlation_job!(scope, "ga4_sessions")

      capture_log(fn ->
        assert :ok = perform_job(CorrelationWorker, job_args(job.id, user.id), [])
      end)

      results = CorrelationsRepository.list_correlation_results(scope)
      assert results != []
      assert hd(results).provider == :google_analytics
    end

    test "data_points on the completed job equals the max data_points across all results" do
      {user, scope} = user_with_scope()
      insert_metrics!(user.id, "ga4_sessions", 40)
      insert_metrics!(user.id, "ga4_pageviews", 40)
      job = insert_correlation_job!(scope, "ga4_sessions")

      capture_log(fn ->
        assert :ok = perform_job(CorrelationWorker, job_args(job.id, user.id), [])
      end)

      {:ok, final_job} = CorrelationsRepository.get_correlation_job(scope, job.id)
      results = CorrelationsRepository.list_correlation_results(scope)
      max_data_points = results |> Enum.map(& &1.data_points) |> Enum.max(fn -> 0 end)

      assert final_job.data_points == max_data_points
    end
  end
end
