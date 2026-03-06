defmodule MetricFlowWeb.IntegrationLive.SyncHistoryTest do
  use MetricFlowTest.ConnCase, async: false

  import ExUnit.CaptureLog
  import Phoenix.LiveViewTest
  import MetricFlowTest.UsersFixtures

  alias MetricFlow.DataSync.SyncHistory
  alias MetricFlow.DataSync.SyncJob
  alias MetricFlow.Integrations.Integration
  alias MetricFlow.Repo

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp insert_integration!(user_id, provider) do
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

  defp insert_sync_job!(user_id, integration_id, provider) do
    %SyncJob{}
    |> SyncJob.changeset(%{
      user_id: user_id,
      integration_id: integration_id,
      provider: provider,
      status: :completed
    })
    |> Repo.insert!()
  end

  defp insert_sync_history!(user_id, integration_id, sync_job_id, overrides \\ %{}) do
    defaults = %{
      user_id: user_id,
      integration_id: integration_id,
      sync_job_id: sync_job_id,
      provider: :google_analytics,
      status: :success,
      records_synced: 42,
      started_at: DateTime.add(DateTime.utc_now(), -120, :second) |> DateTime.truncate(:microsecond),
      completed_at: DateTime.add(DateTime.utc_now(), -60, :second) |> DateTime.truncate(:microsecond)
    }

    attrs = Map.merge(defaults, overrides)

    %SyncHistory{}
    |> SyncHistory.changeset(attrs)
    |> Repo.insert!()
  end

  defp sync_completed_payload(overrides \\ %{}) do
    Map.merge(
      %{
        provider: :google_ads,
        records_synced: 150,
        completed_at: DateTime.utc_now() |> DateTime.truncate(:second)
      },
      overrides
    )
  end

  defp sync_failed_payload(overrides \\ %{}) do
    Map.merge(
      %{
        provider: :facebook_ads,
        reason: "API rate limit exceeded",
        attempt: 1,
        max_attempts: 3
      },
      overrides
    )
  end

  defp yesterday do
    Date.add(Date.utc_today(), -1)
  end

  # ---------------------------------------------------------------------------
  # describe "mount/3"
  # ---------------------------------------------------------------------------

  describe "mount/3" do
    test "renders the Sync History page title for an authenticated user", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/integrations/sync-history")

        assert html =~ "Sync History"
      end)
    end

    test "renders the page subtitle describing sync results", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/integrations/sync-history")

        assert html =~ "View automated sync results and status"
      end)
    end

    test "renders the sync schedule section with data-role=sync-schedule", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/integrations/sync-history")

        assert has_element?(lv, "[data-role='sync-schedule']")
      end)
    end

    test "renders the Automated Sync Schedule heading inside the schedule section", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/integrations/sync-history")

        assert has_element?(lv, "[data-role='sync-schedule']", "Automated Sync Schedule")
      end)
    end

    test "renders Daily at 2:00 AM UTC text in the schedule section", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/integrations/sync-history")

        assert has_element?(lv, "[data-role='sync-schedule']", "Daily at 2:00 AM UTC")
      end)
    end

    test "renders a Daily badge in the schedule section", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/integrations/sync-history")

        assert has_element?(lv, "[data-role='sync-schedule'] .badge-info", "Daily")
      end)
    end

    test "renders the date range section with data-role=date-range", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/integrations/sync-history")

        assert has_element?(lv, "[data-role='date-range']")
      end)
    end

    test "renders the date range ending at yesterday in ISO format", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/integrations/sync-history")

        assert html =~ Date.to_iso8601(yesterday())
      end)
    end

    test "renders 'Showing data through' text in the date range section", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/integrations/sync-history")

        assert has_element?(lv, "[data-role='date-range']", "Showing data through")
      end)
    end

    test "renders the sync history list container with data-role=sync-history", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/integrations/sync-history")

        assert has_element?(lv, "[data-role='sync-history']")
      end)
    end

    test "shows No sync history yet. empty state when there are no entries", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/integrations/sync-history")

        assert html =~ "No sync history yet."
      end)
    end

    test "does not render any sync-history-entry elements in the empty state", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/integrations/sync-history")

        refute has_element?(lv, "[data-role='sync-history-entry']")
      end)
    end

    test "renders a sync history entry for a persisted success record", %{conn: conn} do
      user = user_fixture()
      integration = insert_integration!(user.id, :google_analytics)
      sync_job = insert_sync_job!(user.id, integration.id, :google_analytics)
      insert_sync_history!(user.id, integration.id, sync_job.id, %{
        provider: :google_analytics,
        status: :success,
        records_synced: 75
      })
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/integrations/sync-history")

        assert has_element?(lv, "[data-role='sync-history-entry']")
      end)
    end

    test "does not show the empty state when sync history entries exist", %{conn: conn} do
      user = user_fixture()
      integration = insert_integration!(user.id, :google_analytics)
      sync_job = insert_sync_job!(user.id, integration.id, :google_analytics)
      insert_sync_history!(user.id, integration.id, sync_job.id)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/integrations/sync-history")

        refute html =~ "No sync history yet."
      end)
    end

    test "renders an entry with data-status=success for a successful sync record", %{conn: conn} do
      user = user_fixture()
      integration = insert_integration!(user.id, :google_analytics)
      sync_job = insert_sync_job!(user.id, integration.id, :google_analytics)
      insert_sync_history!(user.id, integration.id, sync_job.id, %{status: :success})
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/integrations/sync-history")

        assert has_element?(lv, "[data-role='sync-history-entry'][data-status='success']")
      end)
    end

    test "renders an entry with data-status=failed for a failed sync record", %{conn: conn} do
      user = user_fixture()
      integration = insert_integration!(user.id, :google_analytics)
      sync_job = insert_sync_job!(user.id, integration.id, :google_analytics)
      insert_sync_history!(user.id, integration.id, sync_job.id, %{
        status: :failed,
        error_message: "timeout"
      })
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/integrations/sync-history")

        assert has_element?(lv, "[data-role='sync-history-entry'][data-status='failed']")
      end)
    end

    test "renders the provider name in the sync history entry", %{conn: conn} do
      user = user_fixture()
      integration = insert_integration!(user.id, :google_ads)
      sync_job = insert_sync_job!(user.id, integration.id, :google_ads)
      insert_sync_history!(user.id, integration.id, sync_job.id, %{provider: :google_ads})
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/integrations/sync-history")

        assert has_element?(lv, "[data-role='sync-provider']", "Google Ads")
      end)
    end

    test "renders a Success badge for a successful sync entry", %{conn: conn} do
      user = user_fixture()
      integration = insert_integration!(user.id, :google_analytics)
      sync_job = insert_sync_job!(user.id, integration.id, :google_analytics)
      insert_sync_history!(user.id, integration.id, sync_job.id, %{status: :success})
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/integrations/sync-history")

        assert has_element?(lv, "[data-role='sync-history-entry'] .badge-success", "Success")
      end)
    end

    test "renders records synced count in a successful sync entry", %{conn: conn} do
      user = user_fixture()
      integration = insert_integration!(user.id, :google_analytics)
      sync_job = insert_sync_job!(user.id, integration.id, :google_analytics)
      insert_sync_history!(user.id, integration.id, sync_job.id, %{
        status: :success,
        records_synced: 200
      })
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/integrations/sync-history")

        assert html =~ "200 records synced"
      end)
    end

    test "renders a Failed badge for a failed sync entry", %{conn: conn} do
      user = user_fixture()
      integration = insert_integration!(user.id, :google_analytics)
      sync_job = insert_sync_job!(user.id, integration.id, :google_analytics)
      insert_sync_history!(user.id, integration.id, sync_job.id, %{
        status: :failed,
        error_message: "API error"
      })
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/integrations/sync-history")

        assert has_element?(lv, "[data-role='sync-history-entry'] .badge-error", "Failed")
      end)
    end

    test "renders the error message for a failed sync entry", %{conn: conn} do
      user = user_fixture()
      integration = insert_integration!(user.id, :google_analytics)
      sync_job = insert_sync_job!(user.id, integration.id, :google_analytics)
      insert_sync_history!(user.id, integration.id, sync_job.id, %{
        status: :failed,
        error_message: "connection refused after retries"
      })
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/integrations/sync-history")

        assert has_element?(lv, "[data-role='sync-error']", "connection refused after retries")
      end)
    end

    test "only shows sync history entries belonging to the authenticated user", %{conn: conn} do
      user = user_fixture()
      other_user = user_fixture()
      other_integration = insert_integration!(other_user.id, :google_analytics)
      other_sync_job = insert_sync_job!(other_user.id, other_integration.id, :google_analytics)
      insert_sync_history!(other_user.id, other_integration.id, other_sync_job.id, %{
        records_synced: 999
      })
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/integrations/sync-history")

        assert html =~ "No sync history yet."
        refute html =~ "999 records synced"
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_info/2 {:sync_completed, payload}"
  # ---------------------------------------------------------------------------

  describe "handle_info/2 {:sync_completed, payload}" do
    test "prepends a new success entry to the sync history list", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/integrations/sync-history")

        send(lv.pid, {:sync_completed, sync_completed_payload()})

        assert has_element?(lv, "[data-role='sync-history-entry']")
      end)
    end

    test "shows the provider name in the new success entry", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/integrations/sync-history")

        send(lv.pid, {:sync_completed, sync_completed_payload(%{provider: :google_ads})})

        assert has_element?(lv, "[data-role='sync-provider']", "Google Ads")
      end)
    end

    test "shows the records synced count in the new success entry", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/integrations/sync-history")

        send(lv.pid, {:sync_completed, sync_completed_payload(%{records_synced: 350})})

        assert render(lv) =~ "350 records synced"
      end)
    end

    test "shows a success entry with data-status=success", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/integrations/sync-history")

        send(lv.pid, {:sync_completed, sync_completed_payload()})

        assert has_element?(lv, "[data-role='sync-history-entry'][data-status='success']")
      end)
    end

    test "shows a Success badge in the new success entry", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/integrations/sync-history")

        send(lv.pid, {:sync_completed, sync_completed_payload()})

        assert has_element?(lv, "[data-role='sync-history-entry'] .badge-success", "Success")
      end)
    end

    test "shows the completion timestamp in the new success entry", %{conn: conn} do
      user = user_fixture()
      completed_at = ~U[2026-02-24 10:30:00Z]
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/integrations/sync-history")

        send(lv.pid, {:sync_completed, sync_completed_payload(%{completed_at: completed_at})})

        assert render(lv) =~ "Completed at"
      end)
    end

    test "removes the empty state after receiving a sync_completed message", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/integrations/sync-history")

        send(lv.pid, {:sync_completed, sync_completed_payload()})

        refute render(lv) =~ "No sync history yet."
      end)
    end

    test "prepends the new entry before any existing persisted entries", %{conn: conn} do
      user = user_fixture()
      integration = insert_integration!(user.id, :google_analytics)
      sync_job = insert_sync_job!(user.id, integration.id, :google_analytics)
      insert_sync_history!(user.id, integration.id, sync_job.id, %{
        provider: :google_analytics,
        records_synced: 10
      })
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/integrations/sync-history")

        send(lv.pid, {:sync_completed, sync_completed_payload(%{provider: :google_ads, records_synced: 999})})

        html = render(lv)

        google_ads_pos = :binary.match(html, "Google Ads") |> elem(0)
        google_analytics_pos = :binary.match(html, "Google Analytics") |> elem(0)

        assert google_ads_pos < google_analytics_pos
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_info/2 {:sync_failed, payload}"
  # ---------------------------------------------------------------------------

  describe "handle_info/2 {:sync_failed, payload}" do
    test "prepends a new failure entry to the sync history list", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/integrations/sync-history")

        send(lv.pid, {:sync_failed, sync_failed_payload()})

        assert has_element?(lv, "[data-role='sync-history-entry']")
      end)
    end

    test "shows the provider name in the new failure entry", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/integrations/sync-history")

        send(lv.pid, {:sync_failed, sync_failed_payload(%{provider: :facebook_ads})})

        assert has_element?(lv, "[data-role='sync-provider']", "Facebook Ads")
      end)
    end

    test "shows a failure entry with data-status=failed", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/integrations/sync-history")

        send(lv.pid, {:sync_failed, sync_failed_payload()})

        assert has_element?(lv, "[data-role='sync-history-entry'][data-status='failed']")
      end)
    end

    test "shows a Failed badge in the new failure entry", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/integrations/sync-history")

        send(lv.pid, {:sync_failed, sync_failed_payload()})

        assert has_element?(lv, "[data-role='sync-history-entry'] .badge-error", "Failed")
      end)
    end

    test "shows the error reason text in the new failure entry", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/integrations/sync-history")

        send(lv.pid, {:sync_failed, sync_failed_payload(%{reason: "API rate limit exceeded"})})

        assert has_element?(lv, "[data-role='sync-error']", "API rate limit exceeded")
      end)
    end

    test "shows retry attempt info when attempt and max_attempts are present", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/integrations/sync-history")

        send(lv.pid, {:sync_failed, sync_failed_payload(%{attempt: 2, max_attempts: 3})})

        assert render(lv) =~ "Attempt 2/3"
      end)
    end

    test "shows Attempt 1/3 text when attempt is 1 of 3", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/integrations/sync-history")

        send(lv.pid, {:sync_failed, sync_failed_payload(%{attempt: 1, max_attempts: 3})})

        assert render(lv) =~ "Attempt 1/3"
      end)
    end

    test "does not show retry info when attempt and max_attempts are absent", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      payload = %{provider: :quickbooks, reason: "token expired"}

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/integrations/sync-history")

        send(lv.pid, {:sync_failed, payload})

        refute render(lv) =~ "Attempt"
      end)
    end

    test "removes the empty state after receiving a sync_failed message", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/integrations/sync-history")

        send(lv.pid, {:sync_failed, sync_failed_payload()})

        refute render(lv) =~ "No sync history yet."
      end)
    end

    test "shows quickbooks provider name when sync_failed payload has quickbooks provider", %{
      conn: conn
    } do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/integrations/sync-history")

        send(lv.pid, {:sync_failed, sync_failed_payload(%{provider: :quickbooks})})

        assert has_element?(lv, "[data-role='sync-provider']", "QuickBooks")
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "authentication"
  # ---------------------------------------------------------------------------

  describe "authentication" do
    test "redirects unauthenticated users to /users/log-in", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} =
               live(conn, ~p"/integrations/sync-history")
    end
  end
end
