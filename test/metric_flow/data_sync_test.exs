defmodule MetricFlow.DataSyncTest do
  use MetricFlowTest.DataCase, async: false
  use Oban.Testing, repo: MetricFlow.Repo

  import MetricFlowTest.UsersFixtures

  alias MetricFlow.DataSync
  alias MetricFlow.DataSync.SyncHistory
  alias MetricFlow.DataSync.SyncJob
  alias MetricFlow.DataSync.SyncWorker
  alias MetricFlow.Integrations.Integration
  alias MetricFlow.Repo
  alias MetricFlow.Users.Scope

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp user_with_scope do
    user = user_fixture()
    scope = Scope.for_user(user)
    {user, scope}
  end

  defp future_expires_at do
    DateTime.add(DateTime.utc_now(), 3_600, :second)
  end

  defp past_expires_at do
    DateTime.add(DateTime.utc_now(), -3_600, :second)
  end

  defp insert_integration!(user_id, provider \\ :google_analytics, overrides \\ %{}) do
    defaults = %{
      user_id: user_id,
      provider: provider,
      access_token: "access-token-#{System.unique_integer([:positive])}",
      refresh_token: "refresh-token-#{System.unique_integer([:positive])}",
      expires_at: future_expires_at(),
      granted_scopes: ["email", "profile"],
      provider_metadata: %{"provider_user_id" => "stub-user-id"}
    }

    attrs = Map.merge(defaults, overrides)

    %Integration{}
    |> Integration.changeset(attrs)
    |> Repo.insert!()
  end

  # An integration whose token is expired and has no refresh token — treated as
  # disconnected by sync_integration/2.
  defp insert_disconnected_integration!(user_id, provider \\ :google_analytics) do
    insert_integration!(user_id, provider, %{
      expires_at: past_expires_at(),
      refresh_token: nil
    })
  end

  defp insert_sync_job!(user_id, integration_id, provider \\ :google_analytics, overrides \\ %{}) do
    attrs =
      Map.merge(
        %{
          user_id: user_id,
          integration_id: integration_id,
          provider: provider,
          status: :pending
        },
        overrides
      )

    %SyncJob{}
    |> SyncJob.changeset(attrs)
    |> Repo.insert!()
  end

  defp insert_sync_history!(
         user_id,
         integration_id,
         sync_job_id,
         provider \\ :google_analytics,
         overrides \\ %{}
       ) do
    started_at =
      DateTime.add(DateTime.utc_now(), -120, :second) |> DateTime.truncate(:microsecond)

    completed_at = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    defaults = %{
      user_id: user_id,
      integration_id: integration_id,
      sync_job_id: sync_job_id,
      provider: provider,
      status: :success,
      records_synced: 10,
      started_at: started_at,
      completed_at: completed_at
    }

    attrs = Map.merge(defaults, overrides)

    %SyncHistory{}
    |> SyncHistory.changeset(attrs)
    |> Repo.insert!()
  end

  # ---------------------------------------------------------------------------
  # sync_integration/2
  # ---------------------------------------------------------------------------

  describe "sync_integration/2" do
    test "returns ok tuple with sync job for connected integration" do
      {user, scope} = user_with_scope()
      _integration = insert_integration!(user.id, :google_analytics)

      assert {:ok, sync_job} = DataSync.sync_integration(scope, :google_analytics)
      assert %SyncJob{} = sync_job
    end

    test "sync job has status :pending" do
      {user, scope} = user_with_scope()
      _integration = insert_integration!(user.id, :google_analytics)

      assert {:ok, sync_job} = DataSync.sync_integration(scope, :google_analytics)
      assert sync_job.status == :pending
    end

    test "Oban job is enqueued with correct args" do
      {user, scope} = user_with_scope()
      integration = insert_integration!(user.id, :google_analytics)

      assert {:ok, sync_job} = DataSync.sync_integration(scope, :google_analytics)

      assert_enqueued(
        worker: SyncWorker,
        args: %{
          "integration_id" => integration.id,
          "user_id" => user.id,
          "sync_job_id" => sync_job.id
        }
      )
    end

    test "returns error tuple with :not_found when integration doesn't exist" do
      {_user, scope} = user_with_scope()

      assert {:error, :not_found} = DataSync.sync_integration(scope, :google_analytics)
    end

    test "returns error tuple with :not_connected when integration exists but is disconnected" do
      {user, scope} = user_with_scope()
      _integration = insert_disconnected_integration!(user.id, :google_analytics)

      assert {:error, :not_connected} = DataSync.sync_integration(scope, :google_analytics)
    end
  end

  # ---------------------------------------------------------------------------
  # schedule_daily_syncs/0
  # ---------------------------------------------------------------------------

  describe "schedule_daily_syncs/0" do
    test "schedules sync jobs for all active integrations" do
      {user_a, _scope_a} = user_with_scope()
      {user_b, _scope_b} = user_with_scope()

      insert_integration!(user_a.id, :google_analytics)
      insert_integration!(user_b.id, :google_ads)

      assert {:ok, count} = DataSync.schedule_daily_syncs()
      assert count >= 2
    end

    test "does not schedule jobs for expired integrations" do
      {user, _scope} = user_with_scope()

      # Expired token with no refresh token — cannot be renewed, must be skipped
      insert_integration!(user.id, :google_analytics, %{
        expires_at: past_expires_at(),
        refresh_token: nil
      })

      assert {:ok, 0} = DataSync.schedule_daily_syncs()
    end

    test "does not schedule jobs for integrations without refresh tokens" do
      {user, _scope} = user_with_scope()

      insert_integration!(user.id, :google_analytics, %{
        refresh_token: nil
      })

      assert {:ok, 0} = DataSync.schedule_daily_syncs()
    end

    test "returns count of scheduled jobs" do
      {user_a, _scope_a} = user_with_scope()
      {user_b, _scope_b} = user_with_scope()

      insert_integration!(user_a.id, :google_analytics)
      insert_integration!(user_b.id, :google_analytics)

      assert {:ok, 2} = DataSync.schedule_daily_syncs()
    end

    test "Oban jobs are enqueued with correct args" do
      {user, _scope} = user_with_scope()
      integration = insert_integration!(user.id, :google_analytics)

      assert {:ok, _count} = DataSync.schedule_daily_syncs()

      assert_enqueued(
        worker: SyncWorker,
        args: %{
          "integration_id" => integration.id,
          "user_id" => user.id
        }
      )
    end
  end

  # ---------------------------------------------------------------------------
  # list_sync_history/2
  # ---------------------------------------------------------------------------

  describe "list_sync_history/2" do
    test "returns list of sync history for scoped user" do
      {user, scope} = user_with_scope()
      integration = insert_integration!(user.id)
      sync_job = insert_sync_job!(user.id, integration.id)

      insert_sync_history!(user.id, integration.id, sync_job.id)
      insert_sync_history!(user.id, integration.id, sync_job.id)

      results = DataSync.list_sync_history(scope)
      assert length(results) == 2
      assert Enum.all?(results, &(&1.user_id == user.id))
    end

    test "returns empty list when user has no sync history" do
      {_user, scope} = user_with_scope()

      assert DataSync.list_sync_history(scope) == []
    end

    test "filters by provider when provider option provided" do
      {user, scope} = user_with_scope()
      integration_ga = insert_integration!(user.id, :google_analytics)
      integration_ads = insert_integration!(user.id, :google_ads)
      sync_job_ga = insert_sync_job!(user.id, integration_ga.id, :google_analytics)
      sync_job_ads = insert_sync_job!(user.id, integration_ads.id, :google_ads)

      insert_sync_history!(user.id, integration_ga.id, sync_job_ga.id, :google_analytics)
      insert_sync_history!(user.id, integration_ads.id, sync_job_ads.id, :google_ads)

      results = DataSync.list_sync_history(scope, provider: :google_analytics)

      assert length(results) == 1
      assert hd(results).provider == :google_analytics
    end

    test "limits results when limit option provided" do
      {user, scope} = user_with_scope()
      integration = insert_integration!(user.id)
      sync_job = insert_sync_job!(user.id, integration.id)

      insert_sync_history!(user.id, integration.id, sync_job.id)
      insert_sync_history!(user.id, integration.id, sync_job.id)
      insert_sync_history!(user.id, integration.id, sync_job.id)

      results = DataSync.list_sync_history(scope, limit: 2)
      assert length(results) == 2
    end

    test "offsets results when offset option provided" do
      {user, scope} = user_with_scope()
      integration = insert_integration!(user.id)
      sync_job = insert_sync_job!(user.id, integration.id)

      insert_sync_history!(user.id, integration.id, sync_job.id)
      insert_sync_history!(user.id, integration.id, sync_job.id)
      insert_sync_history!(user.id, integration.id, sync_job.id)

      results = DataSync.list_sync_history(scope, offset: 1)
      assert length(results) == 2
    end

    test "sync history records are ordered by most recent first" do
      {user, scope} = user_with_scope()
      integration = insert_integration!(user.id)
      sync_job = insert_sync_job!(user.id, integration.id)

      earlier_completed_at =
        DateTime.add(DateTime.utc_now(), -600, :second) |> DateTime.truncate(:microsecond)

      later_completed_at =
        DateTime.add(DateTime.utc_now(), -60, :second) |> DateTime.truncate(:microsecond)

      older =
        insert_sync_history!(user.id, integration.id, sync_job.id, :google_analytics, %{
          completed_at: earlier_completed_at
        })

      newer =
        insert_sync_history!(user.id, integration.id, sync_job.id, :google_analytics, %{
          completed_at: later_completed_at
        })

      results = DataSync.list_sync_history(scope)
      result_ids = Enum.map(results, & &1.id)

      assert result_ids == [newer.id, older.id]
    end
  end

  # ---------------------------------------------------------------------------
  # get_sync_job/2
  # ---------------------------------------------------------------------------

  describe "get_sync_job/2" do
    test "returns ok tuple with sync job when found" do
      {user, scope} = user_with_scope()
      integration = insert_integration!(user.id)
      sync_job = insert_sync_job!(user.id, integration.id)

      assert {:ok, result} = DataSync.get_sync_job(scope, sync_job.id)
      assert result.id == sync_job.id
    end

    test "returns error tuple with :not_found when sync job doesn't exist" do
      {_user, scope} = user_with_scope()

      assert {:error, :not_found} = DataSync.get_sync_job(scope, -1)
    end

    test "returns error tuple with :not_found when sync job belongs to different user" do
      {other_user, _other_scope} = user_with_scope()
      other_integration = insert_integration!(other_user.id)
      other_sync_job = insert_sync_job!(other_user.id, other_integration.id)

      {_user, scope} = user_with_scope()

      assert {:error, :not_found} = DataSync.get_sync_job(scope, other_sync_job.id)
    end
  end

  # ---------------------------------------------------------------------------
  # list_sync_jobs/1
  # ---------------------------------------------------------------------------

  describe "list_sync_jobs/1" do
    test "returns list of sync jobs for scoped user" do
      {user, scope} = user_with_scope()
      integration = insert_integration!(user.id)

      insert_sync_job!(user.id, integration.id)
      insert_sync_job!(user.id, integration.id)

      results = DataSync.list_sync_jobs(scope)
      assert length(results) == 2
      assert Enum.all?(results, &(&1.user_id == user.id))
    end

    test "returns empty list when user has no sync jobs" do
      {_user, scope} = user_with_scope()

      assert DataSync.list_sync_jobs(scope) == []
    end

    test "sync jobs are ordered by most recently created" do
      {user, scope} = user_with_scope()
      integration = insert_integration!(user.id)

      first = insert_sync_job!(user.id, integration.id)
      second = insert_sync_job!(user.id, integration.id)

      results = DataSync.list_sync_jobs(scope)
      result_ids = Enum.map(results, & &1.id)

      assert result_ids == [second.id, first.id]
    end

    test "includes jobs with all statuses (pending, running, completed, failed)" do
      {user, scope} = user_with_scope()
      integration = insert_integration!(user.id)

      for status <- [:pending, :running, :completed, :failed] do
        insert_sync_job!(user.id, integration.id, :google_analytics, %{status: status})
      end

      results = DataSync.list_sync_jobs(scope)
      result_statuses = Enum.map(results, & &1.status) |> Enum.sort()

      assert :pending in result_statuses
      assert :running in result_statuses
      assert :completed in result_statuses
      assert :failed in result_statuses
    end
  end

  # ---------------------------------------------------------------------------
  # cancel_sync_job/2
  # ---------------------------------------------------------------------------

  describe "cancel_sync_job/2" do
    test "returns ok tuple with cancelled sync job for pending job" do
      {user, scope} = user_with_scope()
      integration = insert_integration!(user.id)
      sync_job = insert_sync_job!(user.id, integration.id, :google_analytics, %{status: :pending})

      assert {:ok, cancelled} = DataSync.cancel_sync_job(scope, sync_job.id)
      assert cancelled.status == :cancelled
    end

    test "returns ok tuple with cancelled sync job for running job" do
      {user, scope} = user_with_scope()
      integration = insert_integration!(user.id)
      sync_job = insert_sync_job!(user.id, integration.id, :google_analytics, %{status: :running})

      assert {:ok, cancelled} = DataSync.cancel_sync_job(scope, sync_job.id)
      assert cancelled.status == :cancelled
    end

    test "cancels Oban job when status is pending" do
      {user, scope} = user_with_scope()
      integration = insert_integration!(user.id)
      sync_job = insert_sync_job!(user.id, integration.id, :google_analytics, %{status: :pending})

      assert {:ok, _cancelled} = DataSync.cancel_sync_job(scope, sync_job.id)

      refute_enqueued(
        worker: SyncWorker,
        args: %{"sync_job_id" => sync_job.id}
      )
    end

    test "returns error tuple with :not_found when sync job doesn't exist" do
      {_user, scope} = user_with_scope()

      assert {:error, :not_found} = DataSync.cancel_sync_job(scope, -1)
    end

    test "returns error tuple with :invalid_status when job is already completed" do
      {user, scope} = user_with_scope()
      integration = insert_integration!(user.id)

      sync_job =
        insert_sync_job!(user.id, integration.id, :google_analytics, %{status: :completed})

      assert {:error, :invalid_status} = DataSync.cancel_sync_job(scope, sync_job.id)
    end

    test "returns error tuple with :invalid_status when job is already failed" do
      {user, scope} = user_with_scope()
      integration = insert_integration!(user.id)
      sync_job = insert_sync_job!(user.id, integration.id, :google_analytics, %{status: :failed})

      assert {:error, :invalid_status} = DataSync.cancel_sync_job(scope, sync_job.id)
    end

    test "returns error tuple with :invalid_status when job is already cancelled" do
      {user, scope} = user_with_scope()
      integration = insert_integration!(user.id)

      sync_job =
        insert_sync_job!(user.id, integration.id, :google_analytics, %{status: :cancelled})

      assert {:error, :invalid_status} = DataSync.cancel_sync_job(scope, sync_job.id)
    end
  end

  # ---------------------------------------------------------------------------
  # get_sync_history/2
  # ---------------------------------------------------------------------------

  describe "get_sync_history/2" do
    test "returns ok tuple with sync history when found" do
      {user, scope} = user_with_scope()
      integration = insert_integration!(user.id)
      sync_job = insert_sync_job!(user.id, integration.id)
      history = insert_sync_history!(user.id, integration.id, sync_job.id)

      assert {:ok, result} = DataSync.get_sync_history(scope, history.id)
      assert result.id == history.id
    end

    test "returns error tuple with :not_found when sync history doesn't exist" do
      {_user, scope} = user_with_scope()

      assert {:error, :not_found} = DataSync.get_sync_history(scope, -1)
    end

    test "returns error tuple with :not_found when sync history belongs to different user" do
      {other_user, _other_scope} = user_with_scope()
      other_integration = insert_integration!(other_user.id)
      other_sync_job = insert_sync_job!(other_user.id, other_integration.id)
      other_history = insert_sync_history!(other_user.id, other_integration.id, other_sync_job.id)

      {_user, scope} = user_with_scope()

      assert {:error, :not_found} = DataSync.get_sync_history(scope, other_history.id)
    end
  end
end
