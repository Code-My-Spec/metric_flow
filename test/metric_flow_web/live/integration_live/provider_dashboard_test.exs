defmodule MetricFlowWeb.IntegrationLive.ProviderDashboardTest do
  use MetricFlowTest.ConnCase, async: false

  import ExUnit.CaptureLog
  import Phoenix.LiveViewTest
  import MetricFlowTest.UsersFixtures

  alias MetricFlow.Integrations.Integration
  alias MetricFlow.Repo

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp create_integration(user, provider, opts \\ %{}) do
    defaults = %{
      user_id: user.id,
      provider: provider,
      access_token: "test_token_#{System.unique_integer([:positive])}",
      refresh_token: "test_refresh",
      expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
      granted_scopes: [],
      provider_metadata: %{"email" => user.email}
    }

    %Integration{}
    |> Integration.changeset(Map.merge(defaults, opts))
    |> Repo.insert!()
  end

  defp create_metrics(user, provider, metric_name, count \\ 5) do
    Enum.each(1..count, fn i ->
      %MetricFlow.Metrics.Metric{}
      |> MetricFlow.Metrics.Metric.changeset(%{
        user_id: user.id,
        provider: provider,
        metric_type: "reviews",
        metric_name: metric_name,
        value: :rand.uniform(100) * 1.0,
        recorded_at: DateTime.add(DateTime.utc_now(), -i * 86400, :second),
        dimensions: %{}
      })
      |> Repo.insert!()
    end)
  end

  defp create_sync_history(user, provider, status \\ :success) do
    %MetricFlow.DataSync.SyncHistory{}
    |> MetricFlow.DataSync.SyncHistory.changeset(%{
      user_id: user.id,
      provider: provider,
      status: status,
      records_synced: 42,
      started_at: DateTime.add(DateTime.utc_now(), -3600, :second),
      completed_at: DateTime.utc_now()
    })
    |> Repo.insert!()
  end

  # ---------------------------------------------------------------------------
  # describe "mount/3 (connected provider)"
  # ---------------------------------------------------------------------------

  describe "mount/3 (connected provider)" do
    test "renders the dashboard page for an authenticated user with a connected integration", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)
      create_integration(user, :google_business)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, "/integrations/google_business/dashboard")

        assert html =~ "Google Business"
        assert html =~ "Dashboard"
      end)
    end

    test "shows Connected badge when integration exists", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)
      create_integration(user, :google_business)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, "/integrations/google_business/dashboard")

        assert has_element?(lv, ".badge", "Connected")
      end)
    end

    test "shows connected email from integration metadata", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)
      create_integration(user, :google_business, %{provider_metadata: %{"email" => "test@gmail.com"}})

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, "/integrations/google_business/dashboard")

        assert html =~ "test@gmail.com"
      end)
    end

    test "shows last synced timestamp when sync history exists", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)
      create_integration(user, :google_business)
      create_sync_history(user, :google_business)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, "/integrations/google_business/dashboard")

        assert html =~ "Last synced"
      end)
    end

    test "shows Never synced when no sync history exists", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)
      create_integration(user, :google_business)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, "/integrations/google_business/dashboard")

        assert html =~ "Never synced"
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "mount/3 (empty state)"
  # ---------------------------------------------------------------------------

  describe "mount/3 (empty state)" do
    test "shows empty state when no integration exists for provider", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, "/integrations/google_business/dashboard")

        assert has_element?(lv, "[data-role='empty-state']")
      end)
    end

    test "empty state contains link to connect page", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, "/integrations/google_business/dashboard")

        assert html =~ "/integrations/connect/google_business"
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "mount/3 (invalid provider)"
  # ---------------------------------------------------------------------------

  describe "mount/3 (invalid provider)" do
    test "redirects to integrations page for unrecognized provider", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        assert {:error, {:redirect, %{to: "/integrations"}}} =
                 live(conn, "/integrations/not_a_real_provider/dashboard")
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "authentication"
  # ---------------------------------------------------------------------------

  describe "authentication" do
    test "redirects unauthenticated users to login", %{conn: conn} do
      assert {:error, redirect} = live(conn, "/integrations/google_business/dashboard")

      assert {:redirect, %{to: path}} = redirect
      assert path =~ "/users/log-in"
    end
  end

  # ---------------------------------------------------------------------------
  # describe "metrics section"
  # ---------------------------------------------------------------------------

  describe "metrics section" do
    test "renders metric cards for connected provider", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)
      create_integration(user, :google_business)
      create_metrics(user, :google_business, "review_count")

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, "/integrations/google_business/dashboard")

        assert has_element?(lv, "[data-role='metric-card']")
      end)
    end

    test "renders metric chart containers", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)
      create_integration(user, :google_business)
      create_metrics(user, :google_business, "review_count")

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, "/integrations/google_business/dashboard")

        assert has_element?(lv, "[data-role='metric-chart']")
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "reviews section (google_business)"
  # ---------------------------------------------------------------------------

  describe "reviews section (google_business)" do
    test "renders reviews section for google_business provider", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)
      create_integration(user, :google_business)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, "/integrations/google_business/dashboard")

        assert has_element?(lv, "[data-role='reviews-section']")
      end)
    end

    test "does not render reviews section for non-GBP providers", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)
      create_integration(user, :google_analytics)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, "/integrations/google_analytics/dashboard")

        refute has_element?(lv, "[data-role='reviews-section']")
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "sync history section"
  # ---------------------------------------------------------------------------

  describe "sync history section" do
    test "renders sync history section", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)
      create_integration(user, :google_business)
      create_sync_history(user, :google_business)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, "/integrations/google_business/dashboard")

        assert has_element?(lv, "[data-role='sync-history-section']")
        assert has_element?(lv, "[data-role='sync-history-row']")
      end)
    end

    test "shows success badge for successful syncs", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)
      create_integration(user, :google_business)
      create_sync_history(user, :google_business, :success)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, "/integrations/google_business/dashboard")

        assert has_element?(lv, ".badge-success")
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_event sync_now"
  # ---------------------------------------------------------------------------

  describe "handle_event sync_now" do
    test "shows sync started flash when clicking sync now", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)
      create_integration(user, :google_business)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, "/integrations/google_business/dashboard")

        html = render_click(lv, "sync_now")

        assert html =~ "Sync started"
      end)
    end

    test "renders sync now button with data-role", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)
      create_integration(user, :google_business)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, "/integrations/google_business/dashboard")

        assert has_element?(lv, "[data-role='sync-now']")
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_event change_date_range"
  # ---------------------------------------------------------------------------

  describe "handle_event change_date_range" do
    test "re-renders with updated date range", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)
      create_integration(user, :google_business)
      create_metrics(user, :google_business, "review_count", 30)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, "/integrations/google_business/dashboard")

        html = render_change(lv, "change_date_range", %{"date_range" => "last_7_days"})

        assert html =~ "data-role=\"metric-card\""
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "action bar"
  # ---------------------------------------------------------------------------

  describe "action bar" do
    test "renders date range selector", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)
      create_integration(user, :google_business)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, "/integrations/google_business/dashboard")

        assert html =~ "Last 7 days"
        assert html =~ "Last 30 days"
        assert html =~ "Last 90 days"
      end)
    end

    test "renders refresh button", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)
      create_integration(user, :google_business)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, "/integrations/google_business/dashboard")

        assert has_element?(lv, "[phx-click='refresh']")
      end)
    end
  end
end
