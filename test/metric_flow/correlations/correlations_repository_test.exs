defmodule MetricFlow.Correlations.CorrelationsRepositoryTest do
  use MetricFlowTest.DataCase, async: true

  import MetricFlowTest.UsersFixtures

  alias MetricFlow.Accounts
  alias MetricFlow.Accounts.Account
  alias MetricFlow.Accounts.AccountMember
  alias MetricFlow.Correlations.CorrelationJob
  alias MetricFlow.Correlations.CorrelationResult
  alias MetricFlow.Correlations.CorrelationsRepository
  alias MetricFlow.Repo
  alias MetricFlow.Users.Scope

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp unique_slug, do: "account-#{System.unique_integer([:positive])}"

  defp create_personal_account!(user) do
    {:ok, account} =
      %Account{}
      |> Account.creation_changeset(%{
        name: "#{user.email} Personal",
        slug: unique_slug(),
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

  defp insert_job!(account_id, overrides \\ %{}) do
    attrs =
      Map.merge(
        %{
          account_id: account_id,
          status: :pending,
          goal_metric_name: "revenue"
        },
        overrides
      )

    %CorrelationJob{}
    |> CorrelationJob.changeset(attrs)
    |> Repo.insert!()
  end

  defp valid_result_attrs(account_id, job_id, overrides \\ %{}) do
    Map.merge(
      %{
        account_id: account_id,
        correlation_job_id: job_id,
        metric_name: "sessions",
        goal_metric_name: "revenue",
        coefficient: 0.85,
        optimal_lag: 3,
        data_points: 90,
        calculated_at: DateTime.utc_now()
      },
      overrides
    )
  end

  defp insert_result!(account_id, job_id, overrides \\ %{}) do
    attrs = valid_result_attrs(account_id, job_id, overrides)

    %CorrelationResult{}
    |> CorrelationResult.changeset(attrs)
    |> Repo.insert!()
  end

  # ---------------------------------------------------------------------------
  # list_correlation_results/2
  # ---------------------------------------------------------------------------

  describe "list_correlation_results/2" do
    test "returns list of correlation results scoped to account" do
      {_user, scope} = user_with_scope()
      account_id = Accounts.get_personal_account_id(scope)
      job = insert_job!(account_id)
      insert_result!(account_id, job.id)
      insert_result!(account_id, job.id, %{metric_name: "pageviews"})

      results = CorrelationsRepository.list_correlation_results(scope)

      assert length(results) == 2
    end

    test "returns empty list when no results exist" do
      {_user, scope} = user_with_scope()

      assert CorrelationsRepository.list_correlation_results(scope) == []
    end

    test "filters by goal_metric_name when option provided" do
      {_user, scope} = user_with_scope()
      account_id = Accounts.get_personal_account_id(scope)
      job = insert_job!(account_id, %{goal_metric_name: "revenue"})
      job2 = insert_job!(account_id, %{goal_metric_name: "leads"})
      insert_result!(account_id, job.id, %{goal_metric_name: "revenue"})
      insert_result!(account_id, job2.id, %{metric_name: "clicks", goal_metric_name: "leads"})

      results = CorrelationsRepository.list_correlation_results(scope, goal_metric_name: "revenue")

      assert length(results) == 1
      assert hd(results).goal_metric_name == "revenue"
    end

    test "filters by minimum absolute coefficient threshold" do
      {_user, scope} = user_with_scope()
      account_id = Accounts.get_personal_account_id(scope)
      job = insert_job!(account_id)
      insert_result!(account_id, job.id, %{metric_name: "sessions", coefficient: 0.85})
      insert_result!(account_id, job.id, %{metric_name: "pageviews", coefficient: 0.3})
      insert_result!(account_id, job.id, %{metric_name: "bounces", coefficient: -0.75})

      results = CorrelationsRepository.list_correlation_results(scope, min_coefficient: 0.7)

      assert length(results) == 2
      assert Enum.all?(results, fn r -> abs(r.coefficient) >= 0.7 end)
    end

    test "orders by absolute coefficient descending" do
      {_user, scope} = user_with_scope()
      account_id = Accounts.get_personal_account_id(scope)
      job = insert_job!(account_id)
      insert_result!(account_id, job.id, %{metric_name: "sessions", coefficient: 0.5})
      insert_result!(account_id, job.id, %{metric_name: "pageviews", coefficient: -0.9})
      insert_result!(account_id, job.id, %{metric_name: "clicks", coefficient: 0.7})

      results = CorrelationsRepository.list_correlation_results(scope)
      coefficients = Enum.map(results, fn r -> abs(r.coefficient) end)

      assert coefficients == Enum.sort(coefficients, :desc)
    end

    test "applies limit and offset correctly" do
      {_user, scope} = user_with_scope()
      account_id = Accounts.get_personal_account_id(scope)
      job = insert_job!(account_id)
      insert_result!(account_id, job.id, %{metric_name: "sessions", coefficient: 0.9})
      insert_result!(account_id, job.id, %{metric_name: "pageviews", coefficient: 0.7})
      insert_result!(account_id, job.id, %{metric_name: "clicks", coefficient: 0.5})

      limited = CorrelationsRepository.list_correlation_results(scope, limit: 2)
      assert length(limited) == 2

      offset = CorrelationsRepository.list_correlation_results(scope, limit: 2, offset: 1)
      assert length(offset) == 2
      assert hd(offset).metric_name == "pageviews"
    end

    test "does not return results from other accounts" do
      {_user, scope} = user_with_scope()
      account_id = Accounts.get_personal_account_id(scope)

      {_other_user, other_scope} = user_with_scope()
      other_account_id = Accounts.get_personal_account_id(other_scope)

      job = insert_job!(account_id)
      other_job = insert_job!(other_account_id)

      insert_result!(account_id, job.id)
      insert_result!(other_account_id, other_job.id, %{metric_name: "clicks"})

      results = CorrelationsRepository.list_correlation_results(scope)

      assert length(results) == 1
      assert hd(results).account_id == account_id
    end
  end

  # ---------------------------------------------------------------------------
  # get_correlation_result/2
  # ---------------------------------------------------------------------------

  describe "get_correlation_result/2" do
    test "returns ok tuple with result when found" do
      {_user, scope} = user_with_scope()
      account_id = Accounts.get_personal_account_id(scope)
      job = insert_job!(account_id)
      result = insert_result!(account_id, job.id)

      assert {:ok, found} = CorrelationsRepository.get_correlation_result(scope, result.id)
      assert found.id == result.id
      assert found.metric_name == result.metric_name
    end

    test "returns error :not_found when result doesn't exist" do
      {_user, scope} = user_with_scope()

      assert {:error, :not_found} = CorrelationsRepository.get_correlation_result(scope, -1)
    end

    test "returns error :not_found when result belongs to different account" do
      {_user, scope} = user_with_scope()

      {_other_user, other_scope} = user_with_scope()
      other_account_id = Accounts.get_personal_account_id(other_scope)
      other_job = insert_job!(other_account_id)
      other_result = insert_result!(other_account_id, other_job.id)

      assert {:error, :not_found} = CorrelationsRepository.get_correlation_result(scope, other_result.id)
    end
  end

  # ---------------------------------------------------------------------------
  # create_correlation_result/2
  # ---------------------------------------------------------------------------

  describe "create_correlation_result/2" do
    test "returns ok tuple with created result" do
      {_user, scope} = user_with_scope()
      account_id = Accounts.get_personal_account_id(scope)
      job = insert_job!(account_id)
      attrs = Map.delete(valid_result_attrs(account_id, job.id), :account_id)

      assert {:ok, result} = CorrelationsRepository.create_correlation_result(scope, attrs)
      assert result.id != nil
      assert result.metric_name == "sessions"
      assert result.coefficient == 0.85
    end

    test "sets account_id from Scope" do
      {_user, scope} = user_with_scope()
      account_id = Accounts.get_personal_account_id(scope)
      job = insert_job!(account_id)
      attrs = Map.delete(valid_result_attrs(account_id, job.id), :account_id)

      assert {:ok, result} = CorrelationsRepository.create_correlation_result(scope, attrs)
      assert result.account_id == account_id
    end

    test "returns error changeset for invalid data" do
      {_user, scope} = user_with_scope()

      assert {:error, changeset} = CorrelationsRepository.create_correlation_result(scope, %{})
      refute changeset.valid?
    end

    test "enforces unique constraint on [account_id, correlation_job_id, metric_name, goal_metric_name]" do
      {_user, scope} = user_with_scope()
      account_id = Accounts.get_personal_account_id(scope)
      job = insert_job!(account_id)
      attrs = Map.delete(valid_result_attrs(account_id, job.id), :account_id)

      assert {:ok, _first} = CorrelationsRepository.create_correlation_result(scope, attrs)
      assert {:error, changeset} = CorrelationsRepository.create_correlation_result(scope, attrs)
      refute changeset.valid?
    end
  end

  # ---------------------------------------------------------------------------
  # list_correlation_jobs/1
  # ---------------------------------------------------------------------------

  describe "list_correlation_jobs/1" do
    test "returns list of jobs for scoped account" do
      {_user, scope} = user_with_scope()
      account_id = Accounts.get_personal_account_id(scope)
      insert_job!(account_id)
      insert_job!(account_id, %{goal_metric_name: "leads"})

      results = CorrelationsRepository.list_correlation_jobs(scope)

      assert length(results) == 2
    end

    test "returns empty list when no jobs exist" do
      {_user, scope} = user_with_scope()

      assert CorrelationsRepository.list_correlation_jobs(scope) == []
    end

    test "orders by inserted_at descending" do
      {_user, scope} = user_with_scope()
      account_id = Accounts.get_personal_account_id(scope)

      first = insert_job!(account_id, %{goal_metric_name: "revenue"})
      second = insert_job!(account_id, %{goal_metric_name: "leads"})

      results = CorrelationsRepository.list_correlation_jobs(scope)
      result_ids = Enum.map(results, & &1.id)

      assert result_ids == [second.id, first.id]
    end

    test "does not return jobs from other accounts" do
      {_user, scope} = user_with_scope()
      account_id = Accounts.get_personal_account_id(scope)

      {_other_user, other_scope} = user_with_scope()
      other_account_id = Accounts.get_personal_account_id(other_scope)

      insert_job!(account_id)
      insert_job!(other_account_id, %{goal_metric_name: "leads"})

      results = CorrelationsRepository.list_correlation_jobs(scope)

      assert length(results) == 1
      assert hd(results).account_id == account_id
    end
  end

  # ---------------------------------------------------------------------------
  # get_correlation_job/2
  # ---------------------------------------------------------------------------

  describe "get_correlation_job/2" do
    test "returns ok tuple with job when found" do
      {_user, scope} = user_with_scope()
      account_id = Accounts.get_personal_account_id(scope)
      job = insert_job!(account_id)

      assert {:ok, found} = CorrelationsRepository.get_correlation_job(scope, job.id)
      assert found.id == job.id
      assert found.goal_metric_name == job.goal_metric_name
    end

    test "returns error :not_found when job doesn't exist" do
      {_user, scope} = user_with_scope()

      assert {:error, :not_found} = CorrelationsRepository.get_correlation_job(scope, -1)
    end

    test "returns error :not_found when job belongs to different account" do
      {_user, scope} = user_with_scope()

      {_other_user, other_scope} = user_with_scope()
      other_account_id = Accounts.get_personal_account_id(other_scope)
      other_job = insert_job!(other_account_id)

      assert {:error, :not_found} = CorrelationsRepository.get_correlation_job(scope, other_job.id)
    end
  end

  # ---------------------------------------------------------------------------
  # create_correlation_job/2
  # ---------------------------------------------------------------------------

  describe "create_correlation_job/2" do
    test "returns ok tuple with created job" do
      {_user, scope} = user_with_scope()

      assert {:ok, job} = CorrelationsRepository.create_correlation_job(scope, %{goal_metric_name: "revenue"})
      assert job.id != nil
      assert job.goal_metric_name == "revenue"
    end

    test "sets account_id from Scope" do
      {_user, scope} = user_with_scope()
      account_id = Accounts.get_personal_account_id(scope)

      assert {:ok, job} = CorrelationsRepository.create_correlation_job(scope, %{goal_metric_name: "revenue"})
      assert job.account_id == account_id
    end

    test "defaults status to :pending" do
      {_user, scope} = user_with_scope()

      assert {:ok, job} = CorrelationsRepository.create_correlation_job(scope, %{goal_metric_name: "revenue"})
      assert job.status == :pending
    end

    test "returns error changeset for invalid data" do
      {_user, scope} = user_with_scope()

      assert {:error, changeset} = CorrelationsRepository.create_correlation_job(scope, %{})
      refute changeset.valid?
    end
  end

  # ---------------------------------------------------------------------------
  # update_correlation_job/3
  # ---------------------------------------------------------------------------

  describe "update_correlation_job/3" do
    test "returns ok tuple with updated job" do
      {_user, scope} = user_with_scope()
      account_id = Accounts.get_personal_account_id(scope)
      job = insert_job!(account_id)

      assert {:ok, updated} = CorrelationsRepository.update_correlation_job(scope, job, %{status: :running})
      assert updated.id == job.id
      assert updated.status == :running
    end

    test "updates status field" do
      {_user, scope} = user_with_scope()
      account_id = Accounts.get_personal_account_id(scope)
      job = insert_job!(account_id, %{status: :pending})

      assert {:ok, updated} = CorrelationsRepository.update_correlation_job(scope, job, %{status: :completed})
      assert updated.status == :completed
    end

    test "updates started_at and completed_at timestamps" do
      {_user, scope} = user_with_scope()
      account_id = Accounts.get_personal_account_id(scope)
      job = insert_job!(account_id)
      started_at = DateTime.utc_now() |> DateTime.truncate(:microsecond)
      completed_at = DateTime.add(started_at, 30, :second)

      assert {:ok, updated} =
               CorrelationsRepository.update_correlation_job(scope, job, %{
                 status: :completed,
                 started_at: started_at,
                 completed_at: completed_at
               })

      assert updated.started_at == started_at
      assert updated.completed_at == completed_at
    end

    test "updates results_count and data_points" do
      {_user, scope} = user_with_scope()
      account_id = Accounts.get_personal_account_id(scope)
      job = insert_job!(account_id)

      assert {:ok, updated} =
               CorrelationsRepository.update_correlation_job(scope, job, %{
                 status: :completed,
                 results_count: 42,
                 data_points: 90
               })

      assert updated.results_count == 42
      assert updated.data_points == 90
    end

    test "returns error changeset for invalid status" do
      {_user, scope} = user_with_scope()
      account_id = Accounts.get_personal_account_id(scope)
      job = insert_job!(account_id)

      assert {:error, changeset} =
               CorrelationsRepository.update_correlation_job(scope, job, %{status: :not_a_status})

      refute changeset.valid?
    end
  end

  # ---------------------------------------------------------------------------
  # get_latest_completed_job/1
  # ---------------------------------------------------------------------------

  describe "get_latest_completed_job/1" do
    test "returns most recent completed job" do
      {_user, scope} = user_with_scope()
      account_id = Accounts.get_personal_account_id(scope)

      older_completed_at = DateTime.add(DateTime.utc_now(), -3600, :second) |> DateTime.truncate(:microsecond)
      newer_completed_at = DateTime.utc_now() |> DateTime.truncate(:microsecond)

      insert_job!(account_id, %{status: :completed, completed_at: older_completed_at})
      newer = insert_job!(account_id, %{goal_metric_name: "leads", status: :completed, completed_at: newer_completed_at})

      result = CorrelationsRepository.get_latest_completed_job(scope)

      assert result.id == newer.id
    end

    test "returns nil when no completed jobs exist" do
      {_user, scope} = user_with_scope()

      assert CorrelationsRepository.get_latest_completed_job(scope) == nil
    end

    test "ignores pending, running, and failed jobs" do
      {_user, scope} = user_with_scope()
      account_id = Accounts.get_personal_account_id(scope)
      insert_job!(account_id, %{status: :pending})
      insert_job!(account_id, %{goal_metric_name: "leads", status: :running})
      insert_job!(account_id, %{goal_metric_name: "clicks", status: :failed})

      assert CorrelationsRepository.get_latest_completed_job(scope) == nil
    end

    test "scoped to account" do
      {_user, scope} = user_with_scope()
      account_id = Accounts.get_personal_account_id(scope)

      {_other_user, other_scope} = user_with_scope()
      other_account_id = Accounts.get_personal_account_id(other_scope)

      completed_at = DateTime.utc_now() |> DateTime.truncate(:microsecond)
      insert_job!(other_account_id, %{status: :completed, completed_at: completed_at})
      own_job = insert_job!(account_id, %{goal_metric_name: "leads", status: :completed, completed_at: completed_at})

      result = CorrelationsRepository.get_latest_completed_job(scope)

      assert result.id == own_job.id
      assert result.account_id == account_id
    end
  end

  # ---------------------------------------------------------------------------
  # has_running_job?/1
  # ---------------------------------------------------------------------------

  describe "has_running_job?/1" do
    test "returns true when a pending job exists" do
      {_user, scope} = user_with_scope()
      account_id = Accounts.get_personal_account_id(scope)
      insert_job!(account_id, %{status: :pending})

      assert CorrelationsRepository.has_running_job?(scope) == true
    end

    test "returns true when a running job exists" do
      {_user, scope} = user_with_scope()
      account_id = Accounts.get_personal_account_id(scope)
      insert_job!(account_id, %{status: :running})

      assert CorrelationsRepository.has_running_job?(scope) == true
    end

    test "returns false when only completed/failed jobs exist" do
      {_user, scope} = user_with_scope()
      account_id = Accounts.get_personal_account_id(scope)
      completed_at = DateTime.utc_now() |> DateTime.truncate(:microsecond)
      insert_job!(account_id, %{status: :completed, completed_at: completed_at})
      insert_job!(account_id, %{goal_metric_name: "leads", status: :failed})

      assert CorrelationsRepository.has_running_job?(scope) == false
    end

    test "returns false when no jobs exist" do
      {_user, scope} = user_with_scope()

      assert CorrelationsRepository.has_running_job?(scope) == false
    end
  end
end
