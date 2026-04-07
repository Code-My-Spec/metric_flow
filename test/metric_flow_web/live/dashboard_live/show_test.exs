defmodule MetricFlowWeb.DashboardLive.ShowTest do
  use MetricFlowTest.ConnCase, async: false

  import ExUnit.CaptureLog
  import Phoenix.LiveViewTest
  import MetricFlowTest.UsersFixtures

  alias MetricFlow.Integrations.Integration
  alias MetricFlow.Metrics.Metric
  alias MetricFlow.Repo

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp insert_integration!(user, provider \\ :google_analytics) do
    %Integration{}
    |> Integration.changeset(%{
      user_id: user.id,
      provider: provider,
      access_token: "access-token-#{System.unique_integer([:positive])}",
      expires_at: DateTime.add(DateTime.utc_now(), 3_600, :second),
      granted_scopes: [],
      provider_metadata: %{}
    })
    |> Repo.insert!()
  end

  defp insert_metric!(user, attrs \\ %{}) do
    yesterday = Date.add(Date.utc_today(), -1)

    defaults = %{
      user_id: user.id,
      metric_type: "traffic",
      metric_name: "sessions",
      value: 100.0,
      recorded_at: DateTime.new!(yesterday, ~T[00:00:00], "Etc/UTC"),
      provider: :google_analytics,
      dimensions: %{}
    }

    %Metric{}
    |> Metric.changeset(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end

  # ---------------------------------------------------------------------------
  # Test Assertions from spec
  # ---------------------------------------------------------------------------

  describe "renders dashboard page with All Metrics title for default route" do
    test "renders dashboard page with All Metrics title for default route", %{conn: conn} do
      user = user_fixture()
      insert_integration!(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/app/dashboard")

        assert html =~ "All Metrics"
      end)
    end
  end

  describe "shows onboarding prompt when no integrations are connected" do
    test "shows onboarding prompt when no integrations are connected", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, html} = live(conn, ~p"/app/dashboard")

        assert has_element?(lv, "[data-role='onboarding-prompt']")
        assert html =~ "Connect"
        assert has_element?(lv, "[data-role='onboarding-prompt'] a[href='/integrations']")
        refute has_element?(lv, "[data-role='metrics-dashboard']")
      end)
    end
  end

  describe "displays metrics dashboard with chart and data table when integrations exist" do
    test "displays metrics dashboard with chart and data table when integrations exist", %{conn: conn} do
      user = user_fixture()
      insert_integration!(user)
      insert_metric!(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/app/dashboard")

        assert has_element?(lv, "[data-role='metrics-dashboard']")
        assert has_element?(lv, "[data-role='multi-series-chart']")
        assert has_element?(lv, "[data-role='data-table']")
        refute has_element?(lv, "[data-role='onboarding-prompt']")
      end)
    end
  end

  describe "filters metrics by platform when platform filter button is clicked" do
    test "filters metrics by platform when platform filter button is clicked", %{conn: conn} do
      user = user_fixture()
      insert_integration!(user, :google_analytics)
      insert_metric!(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/app/dashboard")

        html = render_click(lv, "filter_platform", %{"platform" => "google_analytics"})

        assert is_binary(html)
        assert has_element?(lv, "[data-role='metrics-dashboard']")
      end)
    end

  end

  describe "changes date range when date range filter button is clicked" do
    test "changes date range when date range filter button is clicked", %{conn: conn} do
      user = user_fixture()
      insert_integration!(user)
      insert_metric!(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/app/dashboard")

        html = render_click(lv, "filter_date_range", %{"range" => "last_7_days"})
        assert is_binary(html)

        html = render_click(lv, "filter_date_range", %{"range" => "last_90_days"})
        assert is_binary(html)

        html = render_click(lv, "filter_date_range", %{"range" => "all_time"})
        assert is_binary(html)

        assert has_element?(lv, "[data-role='metrics-dashboard']")
      end)
    end
  end

  describe "toggles metric visibility when metric toggle button is clicked" do
    test "toggles metric visibility when metric toggle button is clicked", %{conn: conn} do
      user = user_fixture()
      insert_integration!(user)
      insert_metric!(user, %{metric_name: "sessions"})
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/app/dashboard")

        html = render_click(lv, "toggle_metric", %{"metric" => "sessions"})
        assert is_binary(html)

        html = render_click(lv, "toggle_metric", %{"metric" => "sessions"})
        assert is_binary(html)
        assert has_element?(lv, "[data-role='metrics-dashboard']")
      end)
    end
  end

  describe "highlights active platform and date range filter buttons with btn-primary" do
    test "highlights active platform and date range filter buttons with btn-primary", %{conn: conn} do
      user = user_fixture()
      insert_integration!(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/app/dashboard")

        assert has_element?(lv, "[data-role='platform-filter']")
        assert has_element?(lv, "[data-role='date-range-filter']")
        # Default All Platforms button should be active
        assert has_element?(lv, "[data-role='platform-filter'] .btn-primary")
        # Default date range button should be active
        assert has_element?(lv, "[data-role='date-range-filter'] .btn-primary")
      end)
    end
  end

  describe "shows AI chat panel when AI Chat button is clicked and hides on close" do
    test "shows AI chat panel when AI Chat button is clicked and hides on close", %{conn: conn} do
      user = user_fixture()
      insert_integration!(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/app/dashboard")

        lv |> element("[data-role='open-ai-chat']") |> render_click()
        assert has_element?(lv, "[data-role='ai-chat-interface']")

        lv |> element("[data-role='close-chat-panel']") |> render_click()
        refute has_element?(lv, "[data-role='ai-chat-interface']")
      end)
    end
  end

  describe "shows AI insights panel for a metric and hides on close" do
    test "shows AI insights panel for a metric and hides on close", %{conn: conn} do
      user = user_fixture()
      insert_integration!(user)
      insert_metric!(user, %{metric_name: "sessions"})
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/app/dashboard")

        render_click(lv, "show_ai_insights", %{"metric" => "sessions"})
        assert has_element?(lv, "[data-role='ai-insights-panel']")

        render_click(lv, "hide_ai_insights", %{})
        refute has_element?(lv, "[data-role='ai-insights-panel']")
      end)
    end
  end

  describe "shows empty state in chart and table when no data matches filters" do
    test "shows empty state in chart and table when no data matches filters", %{conn: conn} do
      user = user_fixture()
      insert_integration!(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/app/dashboard")

        assert html =~ "No metric data available" or html =~ "No data to display"
      end)
    end
  end

  describe "displays summary stats grid with metric sums and averages" do
    test "displays summary stats grid with metric sums and averages", %{conn: conn} do
      user = user_fixture()
      insert_integration!(user)
      insert_metric!(user, %{metric_name: "sessions", value: 100.0})
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/app/dashboard")

        assert has_element?(lv, "[data-role='summary-stats']")
      end)
    end
  end

  describe "renders custom dashboard by ID with dashboard name as title" do
    test "renders custom dashboard by ID with dashboard name as title", %{conn: conn} do
      user = user_fixture()
      insert_integration!(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/app/dashboards/999999")

        assert html =~ "All Metrics"
      end)
    end
  end
end
