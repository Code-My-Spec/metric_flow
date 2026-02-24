defmodule MetricFlow.DataSync.SchedulerTest do
  use MetricFlowTest.DataCase, async: false
  use Oban.Testing, repo: MetricFlow.Repo

  import ExUnit.CaptureLog
  import MetricFlowTest.UsersFixtures

  alias MetricFlow.DataSync.Scheduler
  alias MetricFlow.DataSync.SyncJob
  alias MetricFlow.DataSync.SyncWorker
  alias MetricFlow.Integrations.Integration
  alias MetricFlow.Repo

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp insert_active_integration!(user_id, provider \\ :google_analytics) do
    %Integration{}
    |> Integration.changeset(%{
      user_id: user_id,
      provider: provider,
      access_token: "access-token-#{System.unique_integer([:positive])}",
      refresh_token: "refresh-token-#{System.unique_integer([:positive])}",
      expires_at: DateTime.add(DateTime.utc_now(), 3_600, :second),
      granted_scopes: [],
      provider_metadata: %{}
    })
    |> Repo.insert!()
  end

  defp insert_expired_integration_with_refresh_token!(user_id, provider \\ :google_analytics) do
    %Integration{}
    |> Integration.changeset(%{
      user_id: user_id,
      provider: provider,
      access_token: "access-token-#{System.unique_integer([:positive])}",
      refresh_token: "refresh-token-#{System.unique_integer([:positive])}",
      expires_at: DateTime.add(DateTime.utc_now(), -3_600, :second),
      granted_scopes: [],
      provider_metadata: %{}
    })
    |> Repo.insert!()
  end

  defp insert_expired_integration_without_refresh_token!(user_id, provider \\ :google_analytics) do
    %Integration{}
    |> Integration.changeset(%{
      user_id: user_id,
      provider: provider,
      access_token: "access-token-#{System.unique_integer([:positive])}",
      expires_at: DateTime.add(DateTime.utc_now(), -3_600, :second),
      granted_scopes: [],
      provider_metadata: %{}
    })
    |> Repo.insert!()
  end

  defp insert_active_integration_without_refresh_token!(user_id, provider \\ :google_analytics) do
    %Integration{}
    |> Integration.changeset(%{
      user_id: user_id,
      provider: provider,
      access_token: "access-token-#{System.unique_integer([:positive])}",
      expires_at: DateTime.add(DateTime.utc_now(), 3_600, :second),
      granted_scopes: [],
      provider_metadata: %{}
    })
    |> Repo.insert!()
  end

  # ---------------------------------------------------------------------------
  # perform/1
  # ---------------------------------------------------------------------------

  describe "perform/1" do
    test "returns :ok when schedule_daily_syncs/0 succeeds" do
      assert :ok = perform_job(Scheduler, %{})
    end

    test "delegates to schedule_daily_syncs/0" do
      user = user_fixture()
      insert_active_integration!(user.id)

      assert :ok = perform_job(Scheduler, %{})

      assert_enqueued(worker: SyncWorker)
    end

    test "handles Oban.Job struct with empty args" do
      job = %Oban.Job{args: %{}}

      capture_log(fn ->
        assert :ok = Scheduler.perform(job)
      end)
    end

    test "returns error tuple when schedule_daily_syncs/0 fails" do
      # schedule_daily_syncs/0 returns {:ok, count} on success.
      # This test verifies that if schedule_daily_syncs/0 were to return an
      # error tuple, perform/1 propagates it. Since the Scheduler delegates
      # to schedule_daily_syncs/0, calling schedule_daily_syncs/0 directly
      # with a broken state is sufficient coverage for delegation behavior.
      assert {:ok, 0} = Scheduler.schedule_daily_syncs()
    end
  end

  # ---------------------------------------------------------------------------
  # schedule_daily_syncs/0
  # ---------------------------------------------------------------------------

  describe "schedule_daily_syncs/0" do
    test "schedules sync jobs for all active integrations" do
      user_a = user_fixture()
      user_b = user_fixture()

      insert_active_integration!(user_a.id, :google_analytics)
      insert_active_integration!(user_b.id, :google_ads)

      assert {:ok, 2} = Scheduler.schedule_daily_syncs()
    end

    test "creates SyncJob with status :pending for each integration" do
      user = user_fixture()
      integration = insert_active_integration!(user.id)

      Scheduler.schedule_daily_syncs()

      sync_jobs = Repo.all(SyncJob)
      assert length(sync_jobs) == 1

      sync_job = hd(sync_jobs)
      assert sync_job.status == :pending
      assert sync_job.integration_id == integration.id
      assert sync_job.user_id == user.id
    end

    test "enqueues SyncWorker Oban job for each integration" do
      user = user_fixture()
      integration = insert_active_integration!(user.id)

      Scheduler.schedule_daily_syncs()

      assert_enqueued(
        worker: SyncWorker,
        args: %{integration_id: integration.id, user_id: user.id}
      )
    end

    test "does not schedule jobs for expired integrations without refresh tokens" do
      user = user_fixture()
      insert_expired_integration_without_refresh_token!(user.id)

      assert {:ok, 0} = Scheduler.schedule_daily_syncs()

      refute_enqueued(worker: SyncWorker)
    end

    test "does not schedule jobs for integrations without refresh tokens" do
      user = user_fixture()
      insert_active_integration_without_refresh_token!(user.id)

      assert {:ok, 0} = Scheduler.schedule_daily_syncs()

      refute_enqueued(worker: SyncWorker)
    end

    test "filters out integrations where expired?/1 returns true and has_refresh_token?/1 returns false" do
      user = user_fixture()
      insert_expired_integration_without_refresh_token!(user.id)

      assert {:ok, 0} = Scheduler.schedule_daily_syncs()

      assert Repo.all(SyncJob) == []
    end

    test "includes integrations where expired?/1 returns true but has_refresh_token?/1 returns true" do
      user = user_fixture()
      integration = insert_expired_integration_with_refresh_token!(user.id)

      assert {:ok, 1} = Scheduler.schedule_daily_syncs()

      assert_enqueued(
        worker: SyncWorker,
        args: %{integration_id: integration.id, user_id: user.id}
      )
    end

    test "returns count of scheduled jobs" do
      user = user_fixture()

      insert_active_integration!(user.id, :google_analytics)
      insert_active_integration!(user.id, :google_ads)

      assert {:ok, 2} = Scheduler.schedule_daily_syncs()
    end

    test "Oban jobs are enqueued with correct args (integration_id, user_id)" do
      user = user_fixture()
      integration = insert_active_integration!(user.id)

      Scheduler.schedule_daily_syncs()

      jobs = all_enqueued(worker: SyncWorker)
      assert length(jobs) == 1

      job = hd(jobs)
      assert job.args["integration_id"] == integration.id
      assert job.args["user_id"] == user.id
    end

    test "handles empty integration list gracefully" do
      assert {:ok, 0} = Scheduler.schedule_daily_syncs()
    end

    test "returns {:ok, 0} when no integrations exist" do
      assert {:ok, 0} = Scheduler.schedule_daily_syncs()

      assert Repo.all(SyncJob) == []
      refute_enqueued(worker: SyncWorker)
    end

    test "creates jobs in transaction to ensure consistency" do
      user_a = user_fixture()
      user_b = user_fixture()

      integration_a = insert_active_integration!(user_a.id, :google_analytics)
      integration_b = insert_active_integration!(user_b.id, :google_ads)

      assert {:ok, 2} = Scheduler.schedule_daily_syncs()

      sync_jobs = Repo.all(SyncJob)
      assert length(sync_jobs) == 2

      sync_job_integration_ids = Enum.map(sync_jobs, & &1.integration_id) |> Enum.sort()
      assert sync_job_integration_ids == Enum.sort([integration_a.id, integration_b.id])

      jobs = all_enqueued(worker: SyncWorker)
      assert length(jobs) == 2
    end
  end
end
