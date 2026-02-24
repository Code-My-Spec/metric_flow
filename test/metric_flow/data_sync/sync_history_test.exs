defmodule MetricFlow.DataSync.SyncHistoryTest do
  use MetricFlowTest.DataCase, async: true

  import MetricFlowTest.UsersFixtures

  alias MetricFlow.DataSync.SyncHistory
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

  defp insert_sync_job!(user_id, integration_id) do
    %SyncJob{}
    |> SyncJob.changeset(%{
      user_id: user_id,
      integration_id: integration_id,
      provider: :google_analytics,
      status: :completed
    })
    |> Repo.insert!()
  end

  defp valid_attrs(user_id, integration_id, sync_job_id) do
    %{
      user_id: user_id,
      integration_id: integration_id,
      sync_job_id: sync_job_id,
      provider: :google_analytics,
      status: :success,
      records_synced: 42,
      started_at: valid_started_at(),
      completed_at: valid_completed_at()
    }
  end

  defp new_sync_history do
    struct!(SyncHistory, [])
  end

  defp insert_sync_history!(attrs) do
    new_sync_history()
    |> SyncHistory.changeset(attrs)
    |> Repo.insert!()
  end

  # ---------------------------------------------------------------------------
  # changeset/2
  # ---------------------------------------------------------------------------

  describe "changeset/2" do
    test "creates valid changeset with all required fields" do
      user = user_fixture()
      integration = insert_integration!(user.id)
      sync_job = insert_sync_job!(user.id, integration.id)
      attrs = valid_attrs(user.id, integration.id, sync_job.id)

      changeset = SyncHistory.changeset(new_sync_history(), attrs)

      assert changeset.valid?
    end

    test "casts each field attribute correctly (user_id, integration_id, sync_job_id, provider, status, records_synced, error_message, started_at, completed_at)" do
      user = user_fixture()
      integration = insert_integration!(user.id)
      sync_job = insert_sync_job!(user.id, integration.id)
      started_at = valid_started_at()
      completed_at = valid_completed_at()

      attrs = %{
        user_id: user.id,
        integration_id: integration.id,
        sync_job_id: sync_job.id,
        provider: :google_analytics,
        status: :success,
        records_synced: 100,
        error_message: "partial failure on batch 3",
        started_at: started_at,
        completed_at: completed_at
      }

      changeset = SyncHistory.changeset(new_sync_history(), attrs)

      assert get_change(changeset, :user_id) == user.id
      assert get_change(changeset, :integration_id) == integration.id
      assert get_change(changeset, :sync_job_id) == sync_job.id
      assert get_change(changeset, :provider) == :google_analytics
      assert get_change(changeset, :status) == :success
      assert get_change(changeset, :records_synced) == 100
      assert get_change(changeset, :error_message) == "partial failure on batch 3"
      assert get_change(changeset, :started_at) == started_at
      assert get_change(changeset, :completed_at) == completed_at
    end

    test "validates user_id is required" do
      user = user_fixture()
      integration = insert_integration!(user.id)
      sync_job = insert_sync_job!(user.id, integration.id)
      attrs = Map.delete(valid_attrs(user.id, integration.id, sync_job.id), :user_id)

      changeset = SyncHistory.changeset(new_sync_history(), attrs)

      refute changeset.valid?
      assert %{user_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates integration_id is required" do
      user = user_fixture()
      integration = insert_integration!(user.id)
      sync_job = insert_sync_job!(user.id, integration.id)
      attrs = Map.delete(valid_attrs(user.id, integration.id, sync_job.id), :integration_id)

      changeset = SyncHistory.changeset(new_sync_history(), attrs)

      refute changeset.valid?
      assert %{integration_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates sync_job_id is required" do
      user = user_fixture()
      integration = insert_integration!(user.id)
      sync_job = insert_sync_job!(user.id, integration.id)
      attrs = Map.delete(valid_attrs(user.id, integration.id, sync_job.id), :sync_job_id)

      changeset = SyncHistory.changeset(new_sync_history(), attrs)

      refute changeset.valid?
      assert %{sync_job_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates provider is required" do
      user = user_fixture()
      integration = insert_integration!(user.id)
      sync_job = insert_sync_job!(user.id, integration.id)
      attrs = Map.delete(valid_attrs(user.id, integration.id, sync_job.id), :provider)

      changeset = SyncHistory.changeset(new_sync_history(), attrs)

      refute changeset.valid?
      assert %{provider: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates status is required" do
      user = user_fixture()
      integration = insert_integration!(user.id)
      sync_job = insert_sync_job!(user.id, integration.id)
      attrs = Map.delete(valid_attrs(user.id, integration.id, sync_job.id), :status)

      changeset = SyncHistory.changeset(new_sync_history(), attrs)

      refute changeset.valid?
      assert %{status: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates records_synced is required" do
      user = user_fixture()
      integration = insert_integration!(user.id)
      sync_job = insert_sync_job!(user.id, integration.id)
      attrs = Map.delete(valid_attrs(user.id, integration.id, sync_job.id), :records_synced)

      changeset = SyncHistory.changeset(new_sync_history(), attrs)

      refute changeset.valid?
      assert %{records_synced: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates started_at is required" do
      user = user_fixture()
      integration = insert_integration!(user.id)
      sync_job = insert_sync_job!(user.id, integration.id)
      attrs = Map.delete(valid_attrs(user.id, integration.id, sync_job.id), :started_at)

      changeset = SyncHistory.changeset(new_sync_history(), attrs)

      refute changeset.valid?
      assert %{started_at: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates completed_at is required" do
      user = user_fixture()
      integration = insert_integration!(user.id)
      sync_job = insert_sync_job!(user.id, integration.id)
      attrs = Map.delete(valid_attrs(user.id, integration.id, sync_job.id), :completed_at)

      changeset = SyncHistory.changeset(new_sync_history(), attrs)

      refute changeset.valid?
      assert %{completed_at: ["can't be blank"]} = errors_on(changeset)
    end

    test "allows nil error_message as optional" do
      user = user_fixture()
      integration = insert_integration!(user.id)
      sync_job = insert_sync_job!(user.id, integration.id)
      attrs = Map.put(valid_attrs(user.id, integration.id, sync_job.id), :error_message, nil)

      changeset = SyncHistory.changeset(new_sync_history(), attrs)

      assert changeset.valid?
    end

    test "defaults records_synced to 0 when not provided" do
      user = user_fixture()
      integration = insert_integration!(user.id)
      sync_job = insert_sync_job!(user.id, integration.id)

      attrs =
        valid_attrs(user.id, integration.id, sync_job.id)
        |> Map.delete(:records_synced)

      sync_history = insert_sync_history!(Map.put(attrs, :records_synced, 0))

      assert sync_history.records_synced == 0
    end

    test "validates records_synced is >= 0" do
      user = user_fixture()
      integration = insert_integration!(user.id)
      sync_job = insert_sync_job!(user.id, integration.id)
      attrs = Map.put(valid_attrs(user.id, integration.id, sync_job.id), :records_synced, -1)

      changeset = SyncHistory.changeset(new_sync_history(), attrs)

      refute changeset.valid?
      assert %{records_synced: [_]} = errors_on(changeset)
    end

    test "rejects negative values for records_synced" do
      user = user_fixture()
      integration = insert_integration!(user.id)
      sync_job = insert_sync_job!(user.id, integration.id)
      attrs = Map.put(valid_attrs(user.id, integration.id, sync_job.id), :records_synced, -5)

      changeset = SyncHistory.changeset(new_sync_history(), attrs)

      refute changeset.valid?
      assert %{records_synced: [_]} = errors_on(changeset)
    end

    test "accepts 0 for records_synced" do
      user = user_fixture()
      integration = insert_integration!(user.id)
      sync_job = insert_sync_job!(user.id, integration.id)
      attrs = Map.put(valid_attrs(user.id, integration.id, sync_job.id), :records_synced, 0)

      changeset = SyncHistory.changeset(new_sync_history(), attrs)

      assert changeset.valid?
      assert get_change(changeset, :records_synced) == 0
    end

    test "accepts positive integers for records_synced" do
      user = user_fixture()
      integration = insert_integration!(user.id)
      sync_job = insert_sync_job!(user.id, integration.id)
      attrs = Map.put(valid_attrs(user.id, integration.id, sync_job.id), :records_synced, 9999)

      changeset = SyncHistory.changeset(new_sync_history(), attrs)

      assert changeset.valid?
      assert get_change(changeset, :records_synced) == 9999
    end

    test "accepts all valid provider enum values (:google_analytics, :google_ads, :facebook_ads, :quickbooks)" do
      user = user_fixture()
      integration = insert_integration!(user.id)
      sync_job = insert_sync_job!(user.id, integration.id)

      for provider <- [:google_analytics, :google_ads, :facebook_ads, :quickbooks] do
        attrs = %{valid_attrs(user.id, integration.id, sync_job.id) | provider: provider}
        changeset = SyncHistory.changeset(new_sync_history(), attrs)

        assert changeset.valid?, "expected #{provider} to be valid"
        assert get_change(changeset, :provider) == provider
      end
    end

    test "accepts all valid status enum values (:success, :partial_success, :failed)" do
      user = user_fixture()
      integration = insert_integration!(user.id)
      sync_job = insert_sync_job!(user.id, integration.id)

      for status <- [:success, :partial_success, :failed] do
        attrs = %{valid_attrs(user.id, integration.id, sync_job.id) | status: status}
        changeset = SyncHistory.changeset(new_sync_history(), attrs)

        assert changeset.valid?, "expected #{status} to be valid"
        assert get_change(changeset, :status) == status
      end
    end

    test "validates user association exists (assoc_constraint triggers on insert)" do
      user = user_fixture()
      integration = insert_integration!(user.id)
      sync_job = insert_sync_job!(user.id, integration.id)

      attrs = %{
        user_id: -1,
        integration_id: integration.id,
        sync_job_id: sync_job.id,
        provider: :google_analytics,
        status: :success,
        records_synced: 0,
        started_at: valid_started_at(),
        completed_at: valid_completed_at()
      }

      {:error, changeset} =
        new_sync_history()
        |> SyncHistory.changeset(attrs)
        |> Repo.insert()

      assert %{user: ["does not exist"]} = errors_on(changeset)
    end

    test "validates integration association exists (assoc_constraint triggers on insert)" do
      user = user_fixture()
      integration = insert_integration!(user.id)
      sync_job = insert_sync_job!(user.id, integration.id)

      attrs = %{
        user_id: user.id,
        integration_id: -1,
        sync_job_id: sync_job.id,
        provider: :google_analytics,
        status: :success,
        records_synced: 0,
        started_at: valid_started_at(),
        completed_at: valid_completed_at()
      }

      {:error, changeset} =
        new_sync_history()
        |> SyncHistory.changeset(attrs)
        |> Repo.insert()

      assert %{integration: ["does not exist"]} = errors_on(changeset)
    end

    test "validates sync_job association exists (assoc_constraint triggers on insert)" do
      user = user_fixture()
      integration = insert_integration!(user.id)

      attrs = %{
        user_id: user.id,
        integration_id: integration.id,
        sync_job_id: -1,
        provider: :google_analytics,
        status: :success,
        records_synced: 0,
        started_at: valid_started_at(),
        completed_at: valid_completed_at()
      }

      {:error, changeset} =
        new_sync_history()
        |> SyncHistory.changeset(attrs)
        |> Repo.insert()

      assert %{sync_job: ["does not exist"]} = errors_on(changeset)
    end

    test "creates valid changeset for updating existing sync history" do
      user = user_fixture()
      integration = insert_integration!(user.id)
      sync_job = insert_sync_job!(user.id, integration.id)
      sync_history = insert_sync_history!(valid_attrs(user.id, integration.id, sync_job.id))

      update_attrs = %{status: :failed, error_message: "connection timeout"}
      changeset = SyncHistory.changeset(sync_history, update_attrs)

      assert changeset.valid?
      assert get_change(changeset, :status) == :failed
      assert get_change(changeset, :error_message) == "connection timeout"
    end

    test "preserves existing fields when updating subset of attributes" do
      user = user_fixture()
      integration = insert_integration!(user.id)
      sync_job = insert_sync_job!(user.id, integration.id)
      sync_history = insert_sync_history!(valid_attrs(user.id, integration.id, sync_job.id))

      update_attrs = %{records_synced: 99}
      changeset = SyncHistory.changeset(sync_history, update_attrs)

      assert changeset.data.provider == :google_analytics
      assert changeset.data.user_id == user.id
      assert changeset.data.integration_id == integration.id
      assert changeset.data.sync_job_id == sync_job.id
    end

    test "handles empty attributes map gracefully" do
      user = user_fixture()
      integration = insert_integration!(user.id)
      sync_job = insert_sync_job!(user.id, integration.id)
      sync_history = insert_sync_history!(valid_attrs(user.id, integration.id, sync_job.id))

      changeset = SyncHistory.changeset(sync_history, %{})

      assert changeset.valid?
    end
  end

  # ---------------------------------------------------------------------------
  # success?/1
  # ---------------------------------------------------------------------------

  describe "success?/1" do
    test "returns true when status is :success" do
      sync_history = struct!(SyncHistory, status: :success)

      assert SyncHistory.success?(sync_history)
    end

    test "returns false when status is :partial_success" do
      sync_history = struct!(SyncHistory, status: :partial_success)

      refute SyncHistory.success?(sync_history)
    end

    test "returns false when status is :failed" do
      sync_history = struct!(SyncHistory, status: :failed)

      refute SyncHistory.success?(sync_history)
    end

    test "works with sync history that has records_synced > 0" do
      sync_history = struct!(SyncHistory, status: :success, records_synced: 50)

      assert SyncHistory.success?(sync_history)
    end

    test "works with sync history that has records_synced = 0" do
      sync_history = struct!(SyncHistory, status: :success, records_synced: 0)

      assert SyncHistory.success?(sync_history)
    end

    test "works with sync history that has error_message" do
      sync_history = struct!(SyncHistory, status: :failed, error_message: "timeout error")

      refute SyncHistory.success?(sync_history)
    end

    test "works with sync history that has no error_message" do
      sync_history = struct!(SyncHistory, status: :success, error_message: nil)

      assert SyncHistory.success?(sync_history)
    end
  end

  # ---------------------------------------------------------------------------
  # duration/1
  # ---------------------------------------------------------------------------

  describe "duration/1" do
    test "returns duration in seconds between started_at and completed_at" do
      started_at = ~U[2026-01-01 12:00:00.000000Z]
      completed_at = ~U[2026-01-01 12:00:45.000000Z]

      sync_history =
        struct!(SyncHistory,
          status: :success,
          started_at: started_at,
          completed_at: completed_at
        )

      assert SyncHistory.duration(sync_history) == 45
    end

    test "returns positive integer for successful sync" do
      started_at = DateTime.add(DateTime.utc_now(), -30, :second) |> DateTime.truncate(:microsecond)
      completed_at = DateTime.utc_now() |> DateTime.truncate(:microsecond)

      sync_history =
        struct!(SyncHistory,
          status: :success,
          started_at: started_at,
          completed_at: completed_at
        )

      result = SyncHistory.duration(sync_history)

      assert is_integer(result)
      assert result > 0
    end

    test "returns positive integer for failed sync" do
      started_at = DateTime.add(DateTime.utc_now(), -15, :second) |> DateTime.truncate(:microsecond)
      completed_at = DateTime.utc_now() |> DateTime.truncate(:microsecond)

      sync_history =
        struct!(SyncHistory,
          status: :failed,
          started_at: started_at,
          completed_at: completed_at
        )

      result = SyncHistory.duration(sync_history)

      assert is_integer(result)
      assert result > 0
    end

    test "returns positive integer for partially successful sync" do
      started_at = DateTime.add(DateTime.utc_now(), -20, :second) |> DateTime.truncate(:microsecond)
      completed_at = DateTime.utc_now() |> DateTime.truncate(:microsecond)

      sync_history =
        struct!(SyncHistory,
          status: :partial_success,
          started_at: started_at,
          completed_at: completed_at
        )

      result = SyncHistory.duration(sync_history)

      assert is_integer(result)
      assert result > 0
    end

    test "calculates duration using DateTime.diff/2 with :second unit" do
      started_at = ~U[2026-01-01 09:00:00.000000Z]
      completed_at = ~U[2026-01-01 09:05:00.000000Z]

      sync_history =
        struct!(SyncHistory,
          status: :success,
          started_at: started_at,
          completed_at: completed_at
        )

      result = SyncHistory.duration(sync_history)

      assert result == DateTime.diff(completed_at, started_at, :second)
    end

    test "returns 0 when started_at equals completed_at" do
      now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

      sync_history =
        struct!(SyncHistory,
          status: :success,
          started_at: now,
          completed_at: now
        )

      assert SyncHistory.duration(sync_history) == 0
    end

    test "returns correct duration for sync lasting one second" do
      started_at = ~U[2026-01-01 10:00:00.000000Z]
      completed_at = ~U[2026-01-01 10:00:01.000000Z]

      sync_history =
        struct!(SyncHistory,
          status: :success,
          started_at: started_at,
          completed_at: completed_at
        )

      assert SyncHistory.duration(sync_history) == 1
    end

    test "returns correct duration for sync lasting one minute" do
      started_at = ~U[2026-01-01 10:00:00.000000Z]
      completed_at = ~U[2026-01-01 10:01:00.000000Z]

      sync_history =
        struct!(SyncHistory,
          status: :success,
          started_at: started_at,
          completed_at: completed_at
        )

      assert SyncHistory.duration(sync_history) == 60
    end

    test "returns correct duration for sync lasting one hour" do
      started_at = ~U[2026-01-01 10:00:00.000000Z]
      completed_at = ~U[2026-01-01 11:00:00.000000Z]

      sync_history =
        struct!(SyncHistory,
          status: :success,
          started_at: started_at,
          completed_at: completed_at
        )

      assert SyncHistory.duration(sync_history) == 3600
    end

    test "works with utc_datetime_usec precision" do
      started_at = ~U[2026-01-01 12:00:00.000000Z]
      completed_at = ~U[2026-01-01 12:01:30.500000Z]

      sync_history =
        struct!(SyncHistory,
          status: :success,
          started_at: started_at,
          completed_at: completed_at
        )

      assert SyncHistory.duration(sync_history) == 90
    end

    test "works with different providers" do
      started_at = ~U[2026-01-01 08:00:00.000000Z]
      completed_at = ~U[2026-01-01 08:00:10.000000Z]

      for provider <- [:google_analytics, :google_ads, :facebook_ads, :quickbooks] do
        sync_history =
          struct!(SyncHistory,
            status: :success,
            provider: provider,
            started_at: started_at,
            completed_at: completed_at
          )

        assert SyncHistory.duration(sync_history) == 10,
               "expected duration 10 for provider #{provider}"
      end
    end

    test "works with different status values" do
      started_at = ~U[2026-01-01 08:00:00.000000Z]
      completed_at = ~U[2026-01-01 08:00:05.000000Z]

      for status <- [:success, :partial_success, :failed] do
        sync_history =
          struct!(SyncHistory,
            status: status,
            started_at: started_at,
            completed_at: completed_at
          )

        assert SyncHistory.duration(sync_history) == 5,
               "expected duration 5 for status #{status}"
      end
    end
  end
end
