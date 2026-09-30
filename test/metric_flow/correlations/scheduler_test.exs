defmodule MetricFlow.Correlations.SchedulerTest do
  use MetricFlowTest.DataCase, async: false
  use Oban.Testing, repo: MetricFlow.Repo

  import ExUnit.CaptureLog
  import MetricFlowTest.IntegrationsFixtures
  import MetricFlowTest.UsersFixtures

  alias MetricFlow.Accounts.Account
  alias MetricFlow.Accounts.AccountMember
  alias MetricFlow.Correlations.CorrelationWorker
  alias MetricFlow.Correlations.Scheduler
  alias MetricFlow.Metrics.Metric
  alias MetricFlow.Repo
  alias MetricFlow.Users.Scope

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp create_personal_account!(user) do
    unique = System.unique_integer([:positive])

    {:ok, account} =
      %Account{}
      |> Account.creation_changeset(%{
        name: "#{user.email} Personal",
        slug: "personal-#{unique}",
        type: "client",
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

  defp insert_metric!(user_id, overrides) do
    defaults = %{
      user_id: user_id,
      metric_type: "traffic",
      metric_name: "sessions",
      value: 100.0,
      recorded_at: DateTime.utc_now() |> DateTime.truncate(:microsecond),
      provider: :google_analytics,
      dimensions: %{}
    }

    attrs = Map.merge(defaults, overrides)

    %Metric{}
    |> Metric.changeset(attrs)
    |> Repo.insert!()
  end

  # ---------------------------------------------------------------------------
  # perform/1
  # ---------------------------------------------------------------------------

  describe "perform/1" do
    test "returns :ok when schedule_daily_correlations/0 succeeds" do
      assert :ok = perform_job(Scheduler, %{})
    end

    test "delegates to schedule_daily_correlations/0, enqueuing a CorrelationWorker for eligible users" do
      {user, _scope} = user_with_scope()
      integration_fixture(user)
      insert_metric!(user.id, %{metric_name: "sessions", value: 10.0})
      insert_metric!(user.id, %{metric_name: "revenue", value: 500.0})

      assert :ok = perform_job(Scheduler, %{})

      assert_enqueued(worker: CorrelationWorker)
    end

    test "handles Oban.Job struct with empty args" do
      job = %Oban.Job{args: %{}}

      capture_log(fn ->
        assert :ok = Scheduler.perform(job)
      end)
    end

    test "handles no eligible users gracefully" do
      assert :ok = perform_job(Scheduler, %{})

      refute_enqueued(worker: CorrelationWorker)
    end
  end
end
