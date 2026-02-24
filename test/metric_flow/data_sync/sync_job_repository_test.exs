defmodule MetricFlow.DataSync.SyncJobRepositoryTest do
  use MetricFlowTest.DataCase, async: true

  import MetricFlowTest.UsersFixtures

  alias MetricFlow.DataSync.SyncJob
  alias MetricFlow.DataSync.SyncJobRepository
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

  defp insert_integration!(user_id, provider \\ :google_analytics) do
    %Integration{}
    |> Integration.changeset(%{
      user_id: user_id,
      provider: provider,
      access_token: "access-token-#{System.unique_integer([:positive])}",
      expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
      granted_scopes: [],
      provider_metadata: %{}
    })
    |> Repo.insert!()
  end

  defp valid_sync_job_attrs(user_id, integration_id, overrides) do
    Map.merge(
      %{
        user_id: user_id,
        integration_id: integration_id,
        provider: :google_analytics,
        status: :pending
      },
      overrides
    )
  end

  defp insert_sync_job!(user_id, integration_id, overrides \\ %{}) do
    attrs = valid_sync_job_attrs(user_id, integration_id, overrides)

    %SyncJob{}
    |> SyncJob.changeset(attrs)
    |> Repo.insert!()
  end

  # ---------------------------------------------------------------------------
  # list_sync_jobs/1
  # ---------------------------------------------------------------------------

  describe "list_sync_jobs/1" do
    test "returns all sync jobs for scoped user" do
      {user, scope} = user_with_scope()
      integration = insert_integration!(user.id)

      insert_sync_job!(user.id, integration.id)
      insert_sync_job!(user.id, integration.id)

      results = SyncJobRepository.list_sync_jobs(scope)

      assert length(results) == 2
    end

    test "returns empty list when no sync jobs exist" do
      {_user, scope} = user_with_scope()

      assert SyncJobRepository.list_sync_jobs(scope) == []
    end

    test "only returns sync jobs for scoped user" do
      {user, scope} = user_with_scope()
      {other_user, _other_scope} = user_with_scope()

      integration = insert_integration!(user.id)
      other_integration = insert_integration!(other_user.id)

      insert_sync_job!(user.id, integration.id)
      insert_sync_job!(other_user.id, other_integration.id)

      results = SyncJobRepository.list_sync_jobs(scope)

      assert length(results) == 1
      assert hd(results).user_id == user.id
    end

    test "orders by most recently created first" do
      {user, scope} = user_with_scope()
      integration = insert_integration!(user.id)

      first = insert_sync_job!(user.id, integration.id)
      second = insert_sync_job!(user.id, integration.id)

      results = SyncJobRepository.list_sync_jobs(scope)
      result_ids = Enum.map(results, & &1.id)

      assert result_ids == [second.id, first.id]
    end

    test "enforces multi-tenant isolation" do
      {user_a, scope_a} = user_with_scope()
      {user_b, _scope_b} = user_with_scope()

      integration_a = insert_integration!(user_a.id)
      integration_b = insert_integration!(user_b.id)

      insert_sync_job!(user_a.id, integration_a.id)
      insert_sync_job!(user_b.id, integration_b.id)
      insert_sync_job!(user_b.id, integration_b.id)

      results = SyncJobRepository.list_sync_jobs(scope_a)

      assert length(results) == 1
      assert hd(results).user_id == user_a.id
    end

    test "returns jobs with all statuses (pending, running, completed, failed, cancelled)" do
      {user, scope} = user_with_scope()
      integration = insert_integration!(user.id)

      for status <- [:pending, :running, :completed, :failed, :cancelled] do
        insert_sync_job!(user.id, integration.id, %{status: status})
      end

      results = SyncJobRepository.list_sync_jobs(scope)
      result_statuses = Enum.map(results, & &1.status) |> Enum.sort()

      assert result_statuses == [:cancelled, :completed, :failed, :pending, :running]
    end
  end

  # ---------------------------------------------------------------------------
  # get_sync_job/2
  # ---------------------------------------------------------------------------

  describe "get_sync_job/2" do
    test "returns sync job when it exists for scoped user" do
      {user, scope} = user_with_scope()
      integration = insert_integration!(user.id)
      sync_job = insert_sync_job!(user.id, integration.id)

      assert {:ok, result} = SyncJobRepository.get_sync_job(scope, sync_job.id)
      assert result.id == sync_job.id
    end

    test "returns error when sync job doesn't exist" do
      {_user, scope} = user_with_scope()

      assert {:error, :not_found} = SyncJobRepository.get_sync_job(scope, -1)
    end

    test "returns error when sync job exists for different user" do
      {other_user, _other_scope} = user_with_scope()
      other_integration = insert_integration!(other_user.id)
      sync_job = insert_sync_job!(other_user.id, other_integration.id)

      {_user, scope} = user_with_scope()

      assert {:error, :not_found} = SyncJobRepository.get_sync_job(scope, sync_job.id)
    end

    test "enforces multi-tenant isolation" do
      {user_a, scope_a} = user_with_scope()
      {user_b, _scope_b} = user_with_scope()

      integration_a = insert_integration!(user_a.id)
      integration_b = insert_integration!(user_b.id)

      sync_job_a = insert_sync_job!(user_a.id, integration_a.id)
      sync_job_b = insert_sync_job!(user_b.id, integration_b.id)

      assert {:ok, result} = SyncJobRepository.get_sync_job(scope_a, sync_job_a.id)
      assert result.user_id == user_a.id

      assert {:error, :not_found} = SyncJobRepository.get_sync_job(scope_a, sync_job_b.id)
    end

    test "works with any sync job status" do
      {user, scope} = user_with_scope()
      integration = insert_integration!(user.id)

      for status <- [:pending, :running, :completed, :failed, :cancelled] do
        sync_job = insert_sync_job!(user.id, integration.id, %{status: status})

        assert {:ok, result} = SyncJobRepository.get_sync_job(scope, sync_job.id)
        assert result.status == status
      end
    end

    test "loads association data if preloaded" do
      {user, scope} = user_with_scope()
      integration = insert_integration!(user.id)
      sync_job = insert_sync_job!(user.id, integration.id)

      assert {:ok, result} = SyncJobRepository.get_sync_job(scope, sync_job.id)
      assert result.id == sync_job.id
      assert result.user_id == user.id
      assert result.integration_id == integration.id
    end
  end

  # ---------------------------------------------------------------------------
  # create_sync_job/3
  # ---------------------------------------------------------------------------

  describe "create_sync_job/3" do
    test "creates sync job with valid attributes" do
      {user, scope} = user_with_scope()
      integration = insert_integration!(user.id)
      attrs = %{provider: :google_analytics}

      assert {:ok, sync_job} = SyncJobRepository.create_sync_job(scope, integration.id, attrs)
      assert sync_job.id != nil
      assert sync_job.provider == :google_analytics
    end

    test "returns error with invalid provider" do
      {_user, scope} = user_with_scope()
      other_user = user_fixture()
      integration = insert_integration!(other_user.id)
      attrs = %{provider: :not_a_provider}

      assert {:error, changeset} = SyncJobRepository.create_sync_job(scope, integration.id, attrs)
      refute changeset.valid?
    end

    test "returns error with missing required fields" do
      {_user, scope} = user_with_scope()
      other_user = user_fixture()
      integration = insert_integration!(other_user.id)

      assert {:error, changeset} = SyncJobRepository.create_sync_job(scope, integration.id, %{})
      refute changeset.valid?
    end

    test "returns error with non-existent integration_id" do
      {_user, scope} = user_with_scope()
      attrs = %{provider: :google_analytics}

      assert {:error, changeset} = SyncJobRepository.create_sync_job(scope, -1, attrs)
      refute changeset.valid?
    end

    test "returns error with non-existent user_id" do
      user = user_fixture()
      integration = insert_integration!(user.id)

      fake_user = %MetricFlow.Users.User{id: -1}
      scope = Scope.for_user(fake_user)
      attrs = %{provider: :google_analytics}

      assert {:error, changeset} = SyncJobRepository.create_sync_job(scope, integration.id, attrs)
      refute changeset.valid?
    end

    test "defaults status to :pending when not provided" do
      {user, scope} = user_with_scope()
      integration = insert_integration!(user.id)
      attrs = %{provider: :google_analytics}

      assert {:ok, sync_job} = SyncJobRepository.create_sync_job(scope, integration.id, attrs)
      assert sync_job.status == :pending
    end

    test "allows explicit status to be set" do
      {user, scope} = user_with_scope()
      integration = insert_integration!(user.id)
      attrs = %{provider: :google_analytics, status: :running}

      assert {:ok, sync_job} = SyncJobRepository.create_sync_job(scope, integration.id, attrs)
      assert sync_job.status == :running
    end

    test "sets user_id from scope automatically" do
      {user, scope} = user_with_scope()
      integration = insert_integration!(user.id)
      attrs = %{provider: :google_analytics}

      assert {:ok, sync_job} = SyncJobRepository.create_sync_job(scope, integration.id, attrs)
      assert sync_job.user_id == user.id
    end

    test "allows optional started_at and completed_at" do
      {user, scope} = user_with_scope()
      integration = insert_integration!(user.id)
      started_at = DateTime.add(DateTime.utc_now(), -60, :second) |> DateTime.truncate(:microsecond)
      completed_at = DateTime.utc_now() |> DateTime.truncate(:microsecond)

      attrs = %{
        provider: :google_analytics,
        status: :completed,
        started_at: started_at,
        completed_at: completed_at
      }

      assert {:ok, sync_job} = SyncJobRepository.create_sync_job(scope, integration.id, attrs)
      assert sync_job.started_at == started_at
      assert sync_job.completed_at == completed_at
    end

    test "allows optional error_message" do
      {user, scope} = user_with_scope()
      integration = insert_integration!(user.id)
      attrs = %{provider: :google_analytics, status: :failed, error_message: "Something went wrong"}

      assert {:ok, sync_job} = SyncJobRepository.create_sync_job(scope, integration.id, attrs)
      assert sync_job.error_message == "Something went wrong"
    end
  end

  # ---------------------------------------------------------------------------
  # update_sync_job_status/3
  # ---------------------------------------------------------------------------

  describe "update_sync_job_status/3" do
    test "updates status from :pending to :running" do
      {user, scope} = user_with_scope()
      integration = insert_integration!(user.id)
      sync_job = insert_sync_job!(user.id, integration.id, %{status: :pending})

      assert {:ok, updated} = SyncJobRepository.update_sync_job_status(scope, sync_job.id, :running)
      assert updated.status == :running
    end

    test "updates status from :running to :completed" do
      {user, scope} = user_with_scope()
      integration = insert_integration!(user.id)
      sync_job = insert_sync_job!(user.id, integration.id, %{status: :running})

      assert {:ok, updated} = SyncJobRepository.update_sync_job_status(scope, sync_job.id, :completed)
      assert updated.status == :completed
    end

    test "updates status from :running to :failed" do
      {user, scope} = user_with_scope()
      integration = insert_integration!(user.id)
      sync_job = insert_sync_job!(user.id, integration.id, %{status: :running})

      assert {:ok, updated} = SyncJobRepository.update_sync_job_status(scope, sync_job.id, :failed)
      assert updated.status == :failed
    end

    test "sets started_at when transitioning to :running" do
      {user, scope} = user_with_scope()
      integration = insert_integration!(user.id)
      sync_job = insert_sync_job!(user.id, integration.id, %{status: :pending})

      assert {:ok, updated} = SyncJobRepository.update_sync_job_status(scope, sync_job.id, :running)
      assert updated.started_at != nil
    end

    test "sets completed_at when transitioning to :completed" do
      {user, scope} = user_with_scope()
      integration = insert_integration!(user.id)
      sync_job = insert_sync_job!(user.id, integration.id, %{status: :running})

      assert {:ok, updated} = SyncJobRepository.update_sync_job_status(scope, sync_job.id, :completed)
      assert updated.completed_at != nil
    end

    test "sets completed_at when transitioning to :failed" do
      {user, scope} = user_with_scope()
      integration = insert_integration!(user.id)
      sync_job = insert_sync_job!(user.id, integration.id, %{status: :running})

      assert {:ok, updated} = SyncJobRepository.update_sync_job_status(scope, sync_job.id, :failed)
      assert updated.completed_at != nil
    end

    test "sets completed_at when transitioning to :cancelled" do
      {user, scope} = user_with_scope()
      integration = insert_integration!(user.id)
      sync_job = insert_sync_job!(user.id, integration.id, %{status: :running})

      assert {:ok, updated} = SyncJobRepository.update_sync_job_status(scope, sync_job.id, :cancelled)
      assert updated.completed_at != nil
    end

    test "returns error when sync job doesn't exist for scoped user" do
      {_user, scope} = user_with_scope()

      assert {:error, :not_found} = SyncJobRepository.update_sync_job_status(scope, -1, :running)
    end

    test "returns error when sync job exists for different user" do
      {other_user, _other_scope} = user_with_scope()
      other_integration = insert_integration!(other_user.id)
      sync_job = insert_sync_job!(other_user.id, other_integration.id, %{status: :pending})

      {_user, scope} = user_with_scope()

      assert {:error, :not_found} = SyncJobRepository.update_sync_job_status(scope, sync_job.id, :running)
    end

    test "preserves existing timestamps when not transitioning" do
      {user, scope} = user_with_scope()
      integration = insert_integration!(user.id)
      started_at = DateTime.add(DateTime.utc_now(), -120, :second) |> DateTime.truncate(:microsecond)
      sync_job = insert_sync_job!(user.id, integration.id, %{status: :running, started_at: started_at})

      assert {:ok, updated} = SyncJobRepository.update_sync_job_status(scope, sync_job.id, :completed)
      assert DateTime.compare(updated.started_at, started_at) == :eq
    end

    test "enforces multi-tenant isolation" do
      {user_a, scope_a} = user_with_scope()
      {user_b, _scope_b} = user_with_scope()

      integration_a = insert_integration!(user_a.id)
      integration_b = insert_integration!(user_b.id)

      sync_job_a = insert_sync_job!(user_a.id, integration_a.id, %{status: :pending})
      sync_job_b = insert_sync_job!(user_b.id, integration_b.id, %{status: :pending})

      assert {:ok, _updated} = SyncJobRepository.update_sync_job_status(scope_a, sync_job_a.id, :running)
      assert {:error, :not_found} = SyncJobRepository.update_sync_job_status(scope_a, sync_job_b.id, :running)
    end
  end

  # ---------------------------------------------------------------------------
  # cancel_sync_job/2
  # ---------------------------------------------------------------------------

  describe "cancel_sync_job/2" do
    test "cancels sync job with :pending status" do
      {user, scope} = user_with_scope()
      integration = insert_integration!(user.id)
      sync_job = insert_sync_job!(user.id, integration.id, %{status: :pending})

      assert {:ok, cancelled} = SyncJobRepository.cancel_sync_job(scope, sync_job.id)
      assert cancelled.status == :cancelled
    end

    test "cancels sync job with :running status" do
      {user, scope} = user_with_scope()
      integration = insert_integration!(user.id)
      sync_job = insert_sync_job!(user.id, integration.id, %{status: :running})

      assert {:ok, cancelled} = SyncJobRepository.cancel_sync_job(scope, sync_job.id)
      assert cancelled.status == :cancelled
    end

    test "returns error when sync job status is :completed" do
      {user, scope} = user_with_scope()
      integration = insert_integration!(user.id)
      sync_job = insert_sync_job!(user.id, integration.id, %{status: :completed})

      assert {:error, :invalid_status} = SyncJobRepository.cancel_sync_job(scope, sync_job.id)
    end

    test "returns error when sync job status is :failed" do
      {user, scope} = user_with_scope()
      integration = insert_integration!(user.id)
      sync_job = insert_sync_job!(user.id, integration.id, %{status: :failed})

      assert {:error, :invalid_status} = SyncJobRepository.cancel_sync_job(scope, sync_job.id)
    end

    test "returns error when sync job status is :cancelled" do
      {user, scope} = user_with_scope()
      integration = insert_integration!(user.id)
      sync_job = insert_sync_job!(user.id, integration.id, %{status: :cancelled})

      assert {:error, :invalid_status} = SyncJobRepository.cancel_sync_job(scope, sync_job.id)
    end

    test "sets completed_at when cancelling" do
      {user, scope} = user_with_scope()
      integration = insert_integration!(user.id)
      sync_job = insert_sync_job!(user.id, integration.id, %{status: :pending})

      assert {:ok, cancelled} = SyncJobRepository.cancel_sync_job(scope, sync_job.id)
      assert cancelled.completed_at != nil
    end

    test "returns error when sync job doesn't exist for scoped user" do
      {_user, scope} = user_with_scope()

      assert {:error, :not_found} = SyncJobRepository.cancel_sync_job(scope, -1)
    end

    test "returns error when sync job exists for different user" do
      {other_user, _other_scope} = user_with_scope()
      other_integration = insert_integration!(other_user.id)
      sync_job = insert_sync_job!(other_user.id, other_integration.id, %{status: :pending})

      {_user, scope} = user_with_scope()

      assert {:error, :not_found} = SyncJobRepository.cancel_sync_job(scope, sync_job.id)
    end

    test "enforces multi-tenant isolation" do
      {user_a, scope_a} = user_with_scope()
      {user_b, _scope_b} = user_with_scope()

      integration_a = insert_integration!(user_a.id)
      integration_b = insert_integration!(user_b.id)

      sync_job_a = insert_sync_job!(user_a.id, integration_a.id, %{status: :pending})
      sync_job_b = insert_sync_job!(user_b.id, integration_b.id, %{status: :pending})

      assert {:ok, cancelled} = SyncJobRepository.cancel_sync_job(scope_a, sync_job_a.id)
      assert cancelled.status == :cancelled

      assert {:error, :not_found} = SyncJobRepository.cancel_sync_job(scope_a, sync_job_b.id)
    end

    test "only allows cancellation of active jobs" do
      {user, scope} = user_with_scope()
      integration = insert_integration!(user.id)

      for status <- [:completed, :failed, :cancelled] do
        sync_job = insert_sync_job!(user.id, integration.id, %{status: status})
        assert {:error, :invalid_status} = SyncJobRepository.cancel_sync_job(scope, sync_job.id)
      end

      for status <- [:pending, :running] do
        sync_job = insert_sync_job!(user.id, integration.id, %{status: status})
        assert {:ok, cancelled} = SyncJobRepository.cancel_sync_job(scope, sync_job.id)
        assert cancelled.status == :cancelled
      end
    end
  end
end
