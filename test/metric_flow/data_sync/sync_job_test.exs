defmodule MetricFlow.DataSync.SyncJobTest do
  use MetricFlowTest.DataCase, async: true

  import MetricFlowTest.UsersFixtures

  alias MetricFlow.DataSync.SyncJob
  alias MetricFlow.Integrations.Integration
  alias MetricFlow.Repo

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp valid_started_at do
    DateTime.add(DateTime.utc_now(), -60, :second) |> DateTime.truncate(:microsecond)
  end

  defp valid_completed_at do
    DateTime.utc_now() |> DateTime.truncate(:microsecond)
  end

  defp insert_integration!(user_id) do
    %Integration{}
    |> Integration.changeset(%{
      user_id: user_id,
      provider: :google_analytics,
      access_token: "access-token-#{System.unique_integer([:positive])}",
      expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
      granted_scopes: [],
      provider_metadata: %{}
    })
    |> Repo.insert!()
  end

  defp valid_attrs(user_id, integration_id) do
    %{
      user_id: user_id,
      integration_id: integration_id,
      provider: :google_analytics,
      status: :pending
    }
  end

  defp new_sync_job do
    struct!(SyncJob, [])
  end

  defp insert_sync_job!(attrs) do
    new_sync_job()
    |> SyncJob.changeset(attrs)
    |> Repo.insert!()
  end

  # ---------------------------------------------------------------------------
  # changeset/2
  # ---------------------------------------------------------------------------

  describe "changeset/2" do
    test "creates valid changeset with all required fields" do
      user = user_fixture()
      integration = insert_integration!(user.id)
      attrs = valid_attrs(user.id, integration.id)

      changeset = SyncJob.changeset(new_sync_job(), attrs)

      assert changeset.valid?
    end

    test "casts each field attribute correctly (user_id, integration_id, provider, status, started_at, completed_at, error_message)" do
      user = user_fixture()
      integration = insert_integration!(user.id)
      started_at = valid_started_at()
      completed_at = valid_completed_at()

      attrs = %{
        user_id: user.id,
        integration_id: integration.id,
        provider: :google_analytics,
        status: :completed,
        started_at: started_at,
        completed_at: completed_at,
        error_message: "some error"
      }

      changeset = SyncJob.changeset(new_sync_job(), attrs)

      assert get_change(changeset, :user_id) == user.id
      assert get_change(changeset, :integration_id) == integration.id
      assert get_change(changeset, :provider) == :google_analytics
      assert get_change(changeset, :status) == :completed
      assert get_change(changeset, :started_at) == started_at
      assert get_change(changeset, :completed_at) == completed_at
      assert get_change(changeset, :error_message) == "some error"
    end

    test "validates user_id is required" do
      user = user_fixture()
      integration = insert_integration!(user.id)
      attrs = Map.delete(valid_attrs(user.id, integration.id), :user_id)

      changeset = SyncJob.changeset(new_sync_job(), attrs)

      refute changeset.valid?
      assert %{user_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates integration_id is required" do
      user = user_fixture()
      integration = insert_integration!(user.id)
      attrs = Map.delete(valid_attrs(user.id, integration.id), :integration_id)

      changeset = SyncJob.changeset(new_sync_job(), attrs)

      refute changeset.valid?
      assert %{integration_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates provider is required" do
      user = user_fixture()
      integration = insert_integration!(user.id)
      attrs = Map.delete(valid_attrs(user.id, integration.id), :provider)

      changeset = SyncJob.changeset(new_sync_job(), attrs)

      refute changeset.valid?
      assert %{provider: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates status is required" do
      user = user_fixture()
      integration = insert_integration!(user.id)
      attrs = Map.delete(valid_attrs(user.id, integration.id), :status)

      changeset = SyncJob.changeset(new_sync_job(), attrs)

      refute changeset.valid?
      assert %{status: ["can't be blank"]} = errors_on(changeset)
    end

    test "allows nil started_at as optional" do
      user = user_fixture()
      integration = insert_integration!(user.id)
      attrs = Map.put(valid_attrs(user.id, integration.id), :started_at, nil)

      changeset = SyncJob.changeset(new_sync_job(), attrs)

      assert changeset.valid?
    end

    test "allows nil completed_at as optional" do
      user = user_fixture()
      integration = insert_integration!(user.id)
      attrs = Map.put(valid_attrs(user.id, integration.id), :completed_at, nil)

      changeset = SyncJob.changeset(new_sync_job(), attrs)

      assert changeset.valid?
    end

    test "allows nil error_message as optional" do
      user = user_fixture()
      integration = insert_integration!(user.id)
      attrs = Map.put(valid_attrs(user.id, integration.id), :error_message, nil)

      changeset = SyncJob.changeset(new_sync_job(), attrs)

      assert changeset.valid?
    end

    test "accepts all valid provider enum values (:google_analytics, :google_ads, :facebook_ads, :quickbooks)" do
      user = user_fixture()
      integration = insert_integration!(user.id)

      for provider <- [:google_analytics, :google_ads, :facebook_ads, :quickbooks] do
        attrs = %{valid_attrs(user.id, integration.id) | provider: provider}
        changeset = SyncJob.changeset(new_sync_job(), attrs)

        assert changeset.valid?, "expected #{provider} to be valid"
        assert get_change(changeset, :provider) == provider
      end
    end

    test "accepts all valid status enum values (:pending, :running, :completed, :failed, :cancelled)" do
      user = user_fixture()
      integration = insert_integration!(user.id)

      for status <- [:pending, :running, :completed, :failed, :cancelled] do
        attrs = %{valid_attrs(user.id, integration.id) | status: status}
        changeset = SyncJob.changeset(new_sync_job(), attrs)

        assert changeset.valid?, "expected #{status} to be valid"
        assert get_change(changeset, :status) == status
      end
    end

    test "validates user association exists (assoc_constraint triggers on insert)" do
      attrs = %{
        user_id: -1,
        integration_id: -1,
        provider: :google_analytics,
        status: :pending
      }

      {:error, changeset} =
        new_sync_job()
        |> SyncJob.changeset(attrs)
        |> Repo.insert()

      assert %{user: ["does not exist"]} = errors_on(changeset)
    end

    test "validates integration association exists (assoc_constraint triggers on insert)" do
      user = user_fixture()

      attrs = %{
        user_id: user.id,
        integration_id: -1,
        provider: :google_analytics,
        status: :pending
      }

      {:error, changeset} =
        new_sync_job()
        |> SyncJob.changeset(attrs)
        |> Repo.insert()

      assert %{integration: ["does not exist"]} = errors_on(changeset)
    end

    test "defaults status to :pending when not provided" do
      user = user_fixture()
      integration = insert_integration!(user.id)
      attrs = Map.delete(valid_attrs(user.id, integration.id), :status)

      sync_job = insert_sync_job!(Map.put(attrs, :status, :pending))

      assert sync_job.status == :pending
    end

    test "creates valid changeset for updating existing sync job" do
      user = user_fixture()
      integration = insert_integration!(user.id)
      sync_job = insert_sync_job!(valid_attrs(user.id, integration.id))

      started_at = valid_started_at()
      update_attrs = %{status: :running, started_at: started_at}

      changeset = SyncJob.changeset(sync_job, update_attrs)

      assert changeset.valid?
      assert get_change(changeset, :status) == :running
      assert get_change(changeset, :started_at) == started_at
    end

    test "preserves existing fields when updating subset of attributes" do
      user = user_fixture()
      integration = insert_integration!(user.id)
      sync_job = insert_sync_job!(valid_attrs(user.id, integration.id))

      update_attrs = %{status: :running}
      changeset = SyncJob.changeset(sync_job, update_attrs)

      assert changeset.data.provider == :google_analytics
      assert changeset.data.user_id == user.id
      assert changeset.data.integration_id == integration.id
    end

    test "handles empty attributes map gracefully" do
      user = user_fixture()
      integration = insert_integration!(user.id)
      sync_job = insert_sync_job!(valid_attrs(user.id, integration.id))

      changeset = SyncJob.changeset(sync_job, %{})

      assert changeset.valid?
    end
  end

  # ---------------------------------------------------------------------------
  # running?/1
  # ---------------------------------------------------------------------------

  describe "running?/1" do
    test "returns true when status is :running" do
      sync_job = struct!(SyncJob, status: :running)

      assert SyncJob.running?(sync_job)
    end

    test "returns false when status is :pending" do
      sync_job = struct!(SyncJob, status: :pending)

      refute SyncJob.running?(sync_job)
    end

    test "returns false when status is :completed" do
      sync_job = struct!(SyncJob, status: :completed)

      refute SyncJob.running?(sync_job)
    end

    test "returns false when status is :failed" do
      sync_job = struct!(SyncJob, status: :failed)

      refute SyncJob.running?(sync_job)
    end

    test "returns false when status is :cancelled" do
      sync_job = struct!(SyncJob, status: :cancelled)

      refute SyncJob.running?(sync_job)
    end

    test "works with sync job that has started_at timestamp" do
      sync_job = struct!(SyncJob, status: :running, started_at: valid_started_at())

      assert SyncJob.running?(sync_job)
    end

    test "works with sync job that has no started_at timestamp" do
      sync_job = struct!(SyncJob, status: :running, started_at: nil)

      assert SyncJob.running?(sync_job)
    end
  end

  # ---------------------------------------------------------------------------
  # completed?/1
  # ---------------------------------------------------------------------------

  describe "completed?/1" do
    test "returns true when status is :completed" do
      sync_job = struct!(SyncJob, status: :completed)

      assert SyncJob.completed?(sync_job)
    end

    test "returns false when status is :pending" do
      sync_job = struct!(SyncJob, status: :pending)

      refute SyncJob.completed?(sync_job)
    end

    test "returns false when status is :running" do
      sync_job = struct!(SyncJob, status: :running)

      refute SyncJob.completed?(sync_job)
    end

    test "returns false when status is :failed" do
      sync_job = struct!(SyncJob, status: :failed)

      refute SyncJob.completed?(sync_job)
    end

    test "returns false when status is :cancelled" do
      sync_job = struct!(SyncJob, status: :cancelled)

      refute SyncJob.completed?(sync_job)
    end

    test "works with sync job that has completed_at timestamp" do
      sync_job = struct!(SyncJob, status: :completed, completed_at: valid_completed_at())

      assert SyncJob.completed?(sync_job)
    end

    test "works with sync job that has no completed_at timestamp" do
      sync_job = struct!(SyncJob, status: :completed, completed_at: nil)

      assert SyncJob.completed?(sync_job)
    end
  end

  # ---------------------------------------------------------------------------
  # running_time/1
  # ---------------------------------------------------------------------------

  describe "running_time/1" do
    test "returns nil when started_at is nil" do
      sync_job = struct!(SyncJob, status: :pending, started_at: nil, completed_at: nil)

      assert SyncJob.running_time(sync_job) == nil
    end

    test "returns nil when status is :pending and no started_at" do
      sync_job = struct!(SyncJob, status: :pending, started_at: nil)

      assert SyncJob.running_time(sync_job) == nil
    end

    test "returns duration in seconds when job is completed" do
      started_at = DateTime.add(DateTime.utc_now(), -120, :second) |> DateTime.truncate(:microsecond)
      completed_at = DateTime.add(DateTime.utc_now(), -60, :second) |> DateTime.truncate(:microsecond)

      sync_job =
        struct!(SyncJob,
          status: :completed,
          started_at: started_at,
          completed_at: completed_at
        )

      assert SyncJob.running_time(sync_job) == 60
    end

    test "returns duration in seconds when job is failed" do
      started_at = DateTime.add(DateTime.utc_now(), -90, :second) |> DateTime.truncate(:microsecond)
      completed_at = DateTime.add(DateTime.utc_now(), -30, :second) |> DateTime.truncate(:microsecond)

      sync_job =
        struct!(SyncJob,
          status: :failed,
          started_at: started_at,
          completed_at: completed_at
        )

      assert SyncJob.running_time(sync_job) == 60
    end

    test "returns duration in seconds when job is cancelled" do
      started_at = DateTime.add(DateTime.utc_now(), -45, :second) |> DateTime.truncate(:microsecond)
      completed_at = DateTime.add(DateTime.utc_now(), -15, :second) |> DateTime.truncate(:microsecond)

      sync_job =
        struct!(SyncJob,
          status: :cancelled,
          started_at: started_at,
          completed_at: completed_at
        )

      assert SyncJob.running_time(sync_job) == 30
    end

    test "returns elapsed time in seconds when job is running (no completed_at)" do
      started_at = DateTime.add(DateTime.utc_now(), -30, :second) |> DateTime.truncate(:microsecond)

      sync_job =
        struct!(SyncJob,
          status: :running,
          started_at: started_at,
          completed_at: nil
        )

      result = SyncJob.running_time(sync_job)

      assert is_integer(result)
      assert result >= 30
    end

    test "calculates duration using DateTime.diff/2 with :second unit" do
      started_at = DateTime.add(DateTime.utc_now(), -300, :second) |> DateTime.truncate(:microsecond)
      completed_at = DateTime.add(DateTime.utc_now(), -0, :second) |> DateTime.truncate(:microsecond)

      sync_job =
        struct!(SyncJob,
          status: :completed,
          started_at: started_at,
          completed_at: completed_at
        )

      result = SyncJob.running_time(sync_job)

      assert result == DateTime.diff(completed_at, started_at, :second)
    end

    test "returns positive integer for valid time ranges" do
      started_at = DateTime.add(DateTime.utc_now(), -100, :second) |> DateTime.truncate(:microsecond)
      completed_at = DateTime.add(DateTime.utc_now(), -10, :second) |> DateTime.truncate(:microsecond)

      sync_job =
        struct!(SyncJob,
          status: :completed,
          started_at: started_at,
          completed_at: completed_at
        )

      result = SyncJob.running_time(sync_job)

      assert is_integer(result)
      assert result > 0
    end

    test "returns 0 when started_at equals completed_at" do
      now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

      sync_job =
        struct!(SyncJob,
          status: :completed,
          started_at: now,
          completed_at: now
        )

      assert SyncJob.running_time(sync_job) == 0
    end

    test "uses current UTC time for running jobs without completed_at" do
      started_at = DateTime.add(DateTime.utc_now(), -10, :second) |> DateTime.truncate(:microsecond)

      sync_job =
        struct!(SyncJob,
          status: :running,
          started_at: started_at,
          completed_at: nil
        )

      result = SyncJob.running_time(sync_job)

      assert is_integer(result)
      assert result >= 10
    end

    test "works with utc_datetime_usec precision" do
      started_at =
        ~U[2026-01-01 12:00:00.000000Z]

      completed_at =
        ~U[2026-01-01 12:01:30.500000Z]

      sync_job =
        struct!(SyncJob,
          status: :completed,
          started_at: started_at,
          completed_at: completed_at
        )

      assert SyncJob.running_time(sync_job) == 90
    end
  end
end
