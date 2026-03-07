defmodule MetricFlow.CorrelationsTest do
  use MetricFlowTest.DataCase, async: false
  use Oban.Testing, repo: MetricFlow.Repo

  import MetricFlowTest.IntegrationsFixtures
  import MetricFlowTest.UsersFixtures

  alias MetricFlow.Accounts.Account
  alias MetricFlow.Accounts.AccountMember
  alias MetricFlow.Correlations
  alias MetricFlow.Correlations.CorrelationJob
  alias MetricFlow.Correlations.CorrelationsRepository
  alias MetricFlow.Correlations.CorrelationWorker
  alias MetricFlow.Metrics.Metric
  alias MetricFlow.Repo
  alias MetricFlow.Users.Scope

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  # Creates a personal account and membership for the user.
  # CorrelationsRepository.get_account_id/1 calls get_personal_account_id/1
  # which requires a personal account to exist. user_fixture/0 does not create
  # one automatically — this helper provides that setup.
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

  defp valid_recorded_at(offset_days) do
    DateTime.utc_now()
    |> DateTime.add(-offset_days * 86_400, :second)
    |> DateTime.truncate(:microsecond)
  end

  defp insert_metric!(user_id, overrides) do
    defaults = %{
      user_id: user_id,
      metric_type: "traffic",
      metric_name: "sessions",
      value: 100.0,
      recorded_at: valid_recorded_at(1),
      provider: :google_analytics,
      dimensions: %{}
    }

    attrs = Map.merge(defaults, overrides)

    %Metric{}
    |> Metric.changeset(attrs)
    |> Repo.insert!()
  end

  defp insert_correlation_job!(scope, overrides \\ %{}) do
    defaults = %{goal_metric_name: "revenue"}
    attrs = Map.merge(defaults, overrides)
    {:ok, job} = CorrelationsRepository.create_correlation_job(scope, attrs)
    job
  end

  defp insert_completed_correlation_job!(scope, overrides \\ %{}) do
    defaults = %{
      goal_metric_name: "revenue",
      status: :completed,
      data_window_start: Date.utc_today() |> Date.add(-30),
      data_window_end: Date.utc_today(),
      data_points: 30,
      completed_at: DateTime.utc_now() |> DateTime.truncate(:microsecond)
    }

    attrs = Map.merge(defaults, overrides)
    {:ok, job} = CorrelationsRepository.create_correlation_job(scope, attrs)
    job
  end

  defp insert_correlation_result!(scope, job, overrides \\ %{}) do
    defaults = %{
      correlation_job_id: job.id,
      metric_name: "sessions",
      goal_metric_name: job.goal_metric_name,
      coefficient: 0.75,
      optimal_lag: 3,
      data_points: 30,
      calculated_at: DateTime.utc_now() |> DateTime.truncate(:microsecond)
    }

    attrs = Map.merge(defaults, overrides)
    {:ok, result} = CorrelationsRepository.create_correlation_result(scope, attrs)
    result
  end

  defp insert_two_metrics_for_sufficient_data!(user_id) do
    insert_metric!(user_id, %{metric_name: "sessions", value: 10.0})
    insert_metric!(user_id, %{metric_name: "revenue", value: 500.0})
  end

  # ---------------------------------------------------------------------------
  # run_correlations/2
  # ---------------------------------------------------------------------------

  describe "run_correlations/2" do
    test "returns `{:ok, %CorrelationJob{}}` when the user has sufficient data and no running job" do
      {user, scope} = user_with_scope()
      insert_two_metrics_for_sufficient_data!(user.id)

      assert {:ok, %CorrelationJob{}} =
               Correlations.run_correlations(scope, %{goal_metric_name: "revenue"})
    end

    test "created job has status `:pending`" do
      {user, scope} = user_with_scope()
      insert_two_metrics_for_sufficient_data!(user.id)

      {:ok, job} = Correlations.run_correlations(scope, %{goal_metric_name: "revenue"})

      assert job.status == :pending
    end

    test "stores goal_metric_name in the job record" do
      {user, scope} = user_with_scope()
      insert_two_metrics_for_sufficient_data!(user.id)

      {:ok, job} = Correlations.run_correlations(scope, %{goal_metric_name: "revenue"})

      assert job.goal_metric_name == "revenue"
    end

    test "enqueues an Oban CorrelationWorker job with correct job_id and user_id args" do
      {user, scope} = user_with_scope()
      insert_two_metrics_for_sufficient_data!(user.id)

      {:ok, job} = Correlations.run_correlations(scope, %{goal_metric_name: "revenue"})

      assert_enqueued(
        worker: CorrelationWorker,
        args: %{"job_id" => job.id, "user_id" => user.id}
      )
    end

    test "returns `{:error, :insufficient_data}` when the user has fewer than two distinct metrics" do
      {_user, scope} = user_with_scope()

      assert {:error, :insufficient_data} =
               Correlations.run_correlations(scope, %{goal_metric_name: "revenue"})
    end

    test "returns `{:error, :already_running}` when a job with status `:running` already exists for the user" do
      {user, scope} = user_with_scope()
      insert_two_metrics_for_sufficient_data!(user.id)

      insert_correlation_job!(scope, %{goal_metric_name: "revenue", status: :running})

      assert {:error, :already_running} =
               Correlations.run_correlations(scope, %{goal_metric_name: "revenue"})
    end

    test "returns `{:error, :already_running}` when a job with status `:pending` already exists for the user" do
      {user, scope} = user_with_scope()
      insert_two_metrics_for_sufficient_data!(user.id)

      insert_correlation_job!(scope, %{goal_metric_name: "revenue", status: :pending})

      assert {:error, :already_running} =
               Correlations.run_correlations(scope, %{goal_metric_name: "revenue"})
    end
  end

  # ---------------------------------------------------------------------------
  # schedule_daily_correlations/0
  # ---------------------------------------------------------------------------

  describe "schedule_daily_correlations/0" do
    test "schedules jobs for users with at least two distinct metrics and active integrations" do
      {user, _scope} = user_with_scope()
      integration_fixture(user)
      insert_metric!(user.id, %{metric_name: "sessions", value: 10.0})
      insert_metric!(user.id, %{metric_name: "revenue", value: 500.0})

      {:ok, count} = Correlations.schedule_daily_correlations()

      assert count >= 1
    end

    test "skips users with fewer than two distinct metrics" do
      {user, _scope} = user_with_scope()
      integration_fixture(user)
      insert_metric!(user.id, %{metric_name: "sessions", value: 10.0})

      {:ok, count} = Correlations.schedule_daily_correlations()

      assert count == 0
      refute_enqueued(worker: CorrelationWorker)
    end

    test "skips users whose most recent completed job was completed within the last 24 hours" do
      {user, scope} = user_with_scope()
      integration_fixture(user)
      insert_metric!(user.id, %{metric_name: "sessions", value: 10.0})
      insert_metric!(user.id, %{metric_name: "revenue", value: 500.0})

      recent_completed_at =
        DateTime.utc_now()
        |> DateTime.add(-1 * 3600, :second)
        |> DateTime.truncate(:microsecond)

      insert_completed_correlation_job!(scope, %{completed_at: recent_completed_at})

      {:ok, count} = Correlations.schedule_daily_correlations()

      assert count == 0
    end

    test "enqueues a CorrelationWorker Oban job for each eligible user" do
      {user, _scope} = user_with_scope()
      integration_fixture(user)
      insert_metric!(user.id, %{metric_name: "sessions", value: 10.0})
      insert_metric!(user.id, %{metric_name: "revenue", value: 500.0})

      Correlations.schedule_daily_correlations()

      assert_enqueued(worker: CorrelationWorker)
    end

    test "returns `{:ok, count}` with the correct count of scheduled jobs" do
      {user1, _scope1} = user_with_scope()
      {user2, _scope2} = user_with_scope()

      integration_fixture(user1)
      insert_metric!(user1.id, %{metric_name: "sessions", value: 10.0})
      insert_metric!(user1.id, %{metric_name: "revenue", value: 500.0})

      integration_fixture(user2)
      insert_metric!(user2.id, %{metric_name: "sessions", value: 20.0})
      insert_metric!(user2.id, %{metric_name: "revenue", value: 800.0})

      {:ok, count} = Correlations.schedule_daily_correlations()

      assert count == 2
    end

    test "returns `{:ok, 0}` when no users are eligible" do
      {:ok, count} = Correlations.schedule_daily_correlations()

      assert count == 0
    end
  end

  # ---------------------------------------------------------------------------
  # get_latest_correlation_summary/1
  # ---------------------------------------------------------------------------

  describe "get_latest_correlation_summary/1" do
    test "returns a map with results sorted by absolute coefficient descending (strongest correlation first)" do
      {_user, scope} = user_with_scope()
      job = insert_completed_correlation_job!(scope)

      insert_correlation_result!(scope, job, %{metric_name: "weak_metric", coefficient: 0.2})
      insert_correlation_result!(scope, job, %{metric_name: "strong_metric", coefficient: 0.9})
      insert_correlation_result!(scope, job, %{metric_name: "moderate_metric", coefficient: 0.5})

      summary = Correlations.get_latest_correlation_summary(scope)

      coefficients = Enum.map(summary.results, &abs(&1.coefficient))
      assert coefficients == Enum.sort(coefficients, :desc)
      assert hd(summary.results).metric_name == "strong_metric"
    end

    test "includes `last_calculated_at` matching the completed job's `completed_at` timestamp" do
      {_user, scope} = user_with_scope()
      completed_at = DateTime.utc_now() |> DateTime.truncate(:microsecond)
      job = insert_completed_correlation_job!(scope, %{completed_at: completed_at})
      insert_correlation_result!(scope, job)

      summary = Correlations.get_latest_correlation_summary(scope)

      assert summary.last_calculated_at == completed_at
    end

    test "includes `data_window` as a `{start_date, end_date}` tuple from the job record" do
      {_user, scope} = user_with_scope()

      window_start = Date.utc_today() |> Date.add(-30)
      window_end = Date.utc_today()

      job =
        insert_completed_correlation_job!(scope, %{
          data_window_start: window_start,
          data_window_end: window_end
        })

      insert_correlation_result!(scope, job)

      summary = Correlations.get_latest_correlation_summary(scope)

      assert summary.data_window == {window_start, window_end}
    end

    test "includes `data_points_count` matching the job's `data_points` field" do
      {_user, scope} = user_with_scope()
      job = insert_completed_correlation_job!(scope, %{data_points: 45})
      insert_correlation_result!(scope, job)

      summary = Correlations.get_latest_correlation_summary(scope)

      assert summary.data_points_count == 45
    end

    test "includes `goal_metric_name` from the job record" do
      {_user, scope} = user_with_scope()
      job = insert_completed_correlation_job!(scope, %{goal_metric_name: "monthly_revenue"})
      insert_correlation_result!(scope, job, %{goal_metric_name: "monthly_revenue"})

      summary = Correlations.get_latest_correlation_summary(scope)

      assert summary.goal_metric_name == "monthly_revenue"
    end

    test "returns `no_data: true` with empty results when no completed job exists" do
      {_user, scope} = user_with_scope()

      summary = Correlations.get_latest_correlation_summary(scope)

      assert summary.no_data == true
      assert summary.results == []
    end

    test "returns `last_calculated_at: nil` when no completed job exists" do
      {_user, scope} = user_with_scope()

      summary = Correlations.get_latest_correlation_summary(scope)

      assert summary.last_calculated_at == nil
    end

    test "does not return results belonging to another user's scope" do
      {_other_user, other_scope} = user_with_scope()
      other_job = insert_completed_correlation_job!(other_scope)

      insert_correlation_result!(other_scope, other_job, %{
        metric_name: "other_user_metric",
        coefficient: 0.99
      })

      {_user, scope} = user_with_scope()

      summary = Correlations.get_latest_correlation_summary(scope)

      assert summary.results == []
      assert summary.no_data == true
    end
  end

  # ---------------------------------------------------------------------------
  # list_correlation_results/2
  # ---------------------------------------------------------------------------

  describe "list_correlation_results/2" do
    test "returns list of correlation results for scoped user" do
      {_user, scope} = user_with_scope()
      job = insert_completed_correlation_job!(scope)
      insert_correlation_result!(scope, job)

      results = Correlations.list_correlation_results(scope)

      assert length(results) == 1
      assert hd(results).metric_name == "sessions"
    end

    test "returns empty list when no correlations exist" do
      {_user, scope} = user_with_scope()

      assert Correlations.list_correlation_results(scope) == []
    end

    test "filters by goal_metric_name when option provided" do
      {_user, scope} = user_with_scope()
      job = insert_completed_correlation_job!(scope, %{goal_metric_name: "revenue"})
      insert_correlation_result!(scope, job, %{goal_metric_name: "revenue"})

      other_job = insert_completed_correlation_job!(scope, %{goal_metric_name: "profit"})

      insert_correlation_result!(scope, other_job, %{
        metric_name: "clicks",
        goal_metric_name: "profit"
      })

      results = Correlations.list_correlation_results(scope, goal_metric_name: "revenue")

      assert length(results) == 1
      assert hd(results).goal_metric_name == "revenue"
    end

    test "filters by minimum absolute coefficient threshold" do
      {_user, scope} = user_with_scope()
      job = insert_completed_correlation_job!(scope)

      insert_correlation_result!(scope, job, %{
        metric_name: "sessions",
        coefficient: 0.8
      })

      insert_correlation_result!(scope, job, %{
        metric_name: "clicks",
        coefficient: 0.2
      })

      results = Correlations.list_correlation_results(scope, min_coefficient: 0.5)

      assert length(results) == 1
      assert hd(results).metric_name == "sessions"
    end

    test "orders results by absolute coefficient descending (strongest first)" do
      {_user, scope} = user_with_scope()
      job = insert_completed_correlation_job!(scope)

      insert_correlation_result!(scope, job, %{
        metric_name: "weak_metric",
        coefficient: 0.2
      })

      insert_correlation_result!(scope, job, %{
        metric_name: "strong_metric",
        coefficient: 0.9
      })

      insert_correlation_result!(scope, job, %{
        metric_name: "moderate_metric",
        coefficient: 0.5
      })

      results = Correlations.list_correlation_results(scope)
      coefficients = Enum.map(results, &abs(&1.coefficient))

      assert coefficients == Enum.sort(coefficients, :desc)
      assert hd(results).metric_name == "strong_metric"
    end

    test "limits and offsets results correctly" do
      {_user, scope} = user_with_scope()
      job = insert_completed_correlation_job!(scope)

      insert_correlation_result!(scope, job, %{metric_name: "m1", coefficient: 0.9})
      insert_correlation_result!(scope, job, %{metric_name: "m2", coefficient: 0.7})
      insert_correlation_result!(scope, job, %{metric_name: "m3", coefficient: 0.5})

      limited = Correlations.list_correlation_results(scope, limit: 2)
      assert length(limited) == 2

      offset_results = Correlations.list_correlation_results(scope, limit: 2, offset: 1)
      assert length(offset_results) == 2
      assert hd(offset_results).metric_name == "m2"
    end
  end

  # ---------------------------------------------------------------------------
  # get_correlation_result/2
  # ---------------------------------------------------------------------------

  describe "get_correlation_result/2" do
    test "returns ok tuple with correlation result when found" do
      {_user, scope} = user_with_scope()
      job = insert_completed_correlation_job!(scope)
      result = insert_correlation_result!(scope, job)

      assert {:ok, fetched} = Correlations.get_correlation_result(scope, result.id)
      assert fetched.id == result.id
      assert fetched.metric_name == result.metric_name
    end

    test "returns error tuple with :not_found when result doesn't exist" do
      {_user, scope} = user_with_scope()

      assert {:error, :not_found} = Correlations.get_correlation_result(scope, -1)
    end

    test "returns error tuple with :not_found when result belongs to different user" do
      {_other_user, other_scope} = user_with_scope()
      job = insert_completed_correlation_job!(other_scope)
      result = insert_correlation_result!(other_scope, job)

      {_user, scope} = user_with_scope()

      assert {:error, :not_found} = Correlations.get_correlation_result(scope, result.id)
    end
  end

  # ---------------------------------------------------------------------------
  # get_correlation_job/2
  # ---------------------------------------------------------------------------

  describe "get_correlation_job/2" do
    test "returns ok tuple with correlation job when found" do
      {_user, scope} = user_with_scope()
      job = insert_correlation_job!(scope)

      assert {:ok, fetched} = Correlations.get_correlation_job(scope, job.id)
      assert fetched.id == job.id
    end

    test "returns error tuple with :not_found when job doesn't exist" do
      {_user, scope} = user_with_scope()

      assert {:error, :not_found} = Correlations.get_correlation_job(scope, -1)
    end

    test "returns error tuple with :not_found when job belongs to different user" do
      {_other_user, other_scope} = user_with_scope()
      job = insert_correlation_job!(other_scope)

      {_user, scope} = user_with_scope()

      assert {:error, :not_found} = Correlations.get_correlation_job(scope, job.id)
    end
  end

  # ---------------------------------------------------------------------------
  # list_correlation_jobs/1
  # ---------------------------------------------------------------------------

  describe "list_correlation_jobs/1" do
    test "returns list of correlation jobs for scoped user" do
      {_user, scope} = user_with_scope()
      insert_correlation_job!(scope)
      insert_correlation_job!(scope, %{goal_metric_name: "profit"})

      jobs = Correlations.list_correlation_jobs(scope)

      assert length(jobs) == 2
    end

    test "returns empty list when no jobs exist" do
      {_user, scope} = user_with_scope()

      assert Correlations.list_correlation_jobs(scope) == []
    end

    test "orders by most recently created" do
      {_user, scope} = user_with_scope()

      first_job = insert_correlation_job!(scope, %{goal_metric_name: "revenue"})
      second_job = insert_correlation_job!(scope, %{goal_metric_name: "profit"})

      jobs = Correlations.list_correlation_jobs(scope)
      job_ids = Enum.map(jobs, & &1.id)

      assert job_ids == [second_job.id, first_job.id]
    end
  end
end
