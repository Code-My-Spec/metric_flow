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

  # ---------------------------------------------------------------------------
  # Test Assertions from spec
  # ---------------------------------------------------------------------------

  describe "renders sync history page with header and schedule section" do
    test "renders sync history page with header and schedule section", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, html} = live(conn, ~p"/integrations/sync-history")

        assert html =~ "Sync History"
        assert html =~ "View automated sync results and status"
        assert has_element?(lv, "[data-role='sync-schedule']")
        assert has_element?(lv, "[data-role='sync-schedule']", "Automated Sync Schedule")
        assert has_element?(lv, "[data-role='sync-schedule']", "Daily at 2:00 AM UTC")
        assert has_element?(lv, "[data-role='sync-schedule'] .badge-info", "Daily")
      end)
    end
  end

  describe "shows date range ending at yesterday with today excluded" do
    test "shows date range ending at yesterday with today excluded", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, html} = live(conn, ~p"/integrations/sync-history")

        yesterday = Date.add(Date.utc_today(), -1)
        assert html =~ Date.to_iso8601(yesterday)
        assert has_element?(lv, "[data-role='date-range']", "Showing data through")
        assert html =~ "today excluded"
      end)
    end
  end

  describe "shows empty state when no sync history or events exist" do
    test "shows empty state when no sync history or events exist", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, html} = live(conn, ~p"/integrations/sync-history")

        assert html =~ "No sync history yet."
        refute has_element?(lv, "[data-role='sync-history-entry']")
      end)
    end
  end

  describe "displays persisted success entries with provider name, badge, and records count" do
    test "displays persisted success entries with provider name, badge, and records count", %{conn: conn} do
      user = user_fixture()
      integration = insert_integration!(user.id, :google_ads)
      sync_job = insert_sync_job!(user.id, integration.id, :google_ads)
      insert_sync_history!(user.id, integration.id, sync_job.id, %{
        provider: :google_ads,
        status: :success,
        records_synced: 200
      })
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, html} = live(conn, ~p"/integrations/sync-history")

        assert has_element?(lv, "[data-role='sync-history-entry'][data-status='success']")
        assert has_element?(lv, "[data-role='sync-provider']", "Google Ads")
        assert has_element?(lv, "[data-role='sync-history-entry'] .badge-success", "Success")
        assert html =~ "200 records synced"
        refute html =~ "No sync history yet."
      end)
    end
  end

  describe "displays persisted failed entries with provider name, badge, and error message" do
    test "displays persisted failed entries with provider name, badge, and error message", %{conn: conn} do
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

        assert has_element?(lv, "[data-role='sync-history-entry'][data-status='failed']")
        assert has_element?(lv, "[data-role='sync-history-entry'] .badge-error", "Failed")
        assert has_element?(lv, "[data-role='sync-error']", "connection refused after retries")
      end)
    end
  end

  describe "filters entries by status when filter buttons are clicked" do
    test "filters entries by status when filter buttons are clicked", %{conn: conn} do
      user = user_fixture()
      integration = insert_integration!(user.id, :google_analytics)
      sync_job = insert_sync_job!(user.id, integration.id, :google_analytics)
      insert_sync_history!(user.id, integration.id, sync_job.id, %{status: :success, records_synced: 10})
      insert_sync_history!(user.id, integration.id, sync_job.id, %{
        status: :failed,
        error_message: "timeout",
        started_at: DateTime.add(DateTime.utc_now(), -200, :second) |> DateTime.truncate(:microsecond),
        completed_at: DateTime.add(DateTime.utc_now(), -180, :second) |> DateTime.truncate(:microsecond)
      })
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/integrations/sync-history")

        lv |> element("[data-role='filter-success']") |> render_click()

        assert has_element?(lv, "[data-role='sync-history-entry'][data-status='success']")
        refute has_element?(lv, "[data-role='sync-history-entry'][data-status='failed']")
      end)
    end
  end

  describe "highlights the active filter button with btn-primary" do
    test "highlights the active filter button with btn-primary", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/integrations/sync-history")

        assert has_element?(lv, "[data-role='filter-all'].btn-primary")
        assert has_element?(lv, "[data-role='filter-success'].btn-ghost")
        assert has_element?(lv, "[data-role='filter-failed'].btn-ghost")
      end)
    end
  end

  describe "prepends live sync_completed events to the top of the history list" do
    test "prepends live sync_completed events to the top of the history list", %{conn: conn} do
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
        assert html =~ "999 records synced"
        refute html =~ "No sync history yet."

        google_ads_pos = :binary.match(html, "Google Ads") |> elem(0)
        google_analytics_pos = :binary.match(html, "Google Analytics") |> elem(0)
        assert google_ads_pos < google_analytics_pos
      end)
    end
  end

  describe "prepends live sync_failed events with error reason and optional retry info" do
    test "prepends live sync_failed events with error reason and optional retry info", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/integrations/sync-history")

        send(lv.pid, {:sync_failed, sync_failed_payload(%{
          provider: :facebook_ads,
          reason: "API rate limit exceeded",
          attempt: 2,
          max_attempts: 3
        })})

        assert has_element?(lv, "[data-role='sync-history-entry'][data-status='failed']")
        assert has_element?(lv, "[data-role='sync-provider']", "Facebook Ads")
        assert has_element?(lv, "[data-role='sync-error']", "API rate limit exceeded")
        assert render(lv) =~ "Attempt 2/3"
      end)
    end
  end

  describe "shows Initial Sync badge for entries with sync_type initial" do
    test "shows Initial Sync badge for entries with sync_type initial", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/integrations/sync-history")

        send(lv.pid, {:sync_completed, sync_completed_payload(%{sync_type: :initial})})

        assert has_element?(lv, "[data-sync-type='initial']", "Initial Sync")
      end)
    end
  end
end
