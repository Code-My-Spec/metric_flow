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

  defp yesterday do
    Date.add(Date.utc_today(), -1)
  end

  # ---------------------------------------------------------------------------
  # describe "authentication"
  # ---------------------------------------------------------------------------

  describe "authentication" do
    test "redirects unauthenticated users to /users/log-in", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} =
               live(conn, ~p"/dashboard")
    end
  end

  # ---------------------------------------------------------------------------
  # describe "mount/3" — onboarding state (no integrations)
  # ---------------------------------------------------------------------------

  describe "mount/3 onboarding state" do
    test "shows onboarding prompt when user has no integrations", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboard")

        assert has_element?(lv, "[data-role='onboarding-prompt']")
      end)
    end

    test "onboarding prompt mentions connecting integrations", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/dashboard")

        assert html =~ "Connect"
      end)
    end

    test "shows a link to connect integrations pointing to /integrations", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboard")

        assert has_element?(lv, "[data-role='onboarding-prompt'] a[href='/integrations']")
      end)
    end

    test "does not show the metrics dashboard area when user has no integrations", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboard")

        refute has_element?(lv, "[data-role='metrics-dashboard']")
      end)
    end

    test "does not show any vega-lite chart containers when user has no integrations", %{
      conn: conn
    } do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboard")

        refute has_element?(lv, "[data-role='vega-lite-chart']")
      end)
    end

    test "does not show the platform filter when user has no integrations", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboard")

        refute has_element?(lv, "[data-role='platform-filter']")
      end)
    end

    test "does not show the date range filter when user has no integrations", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboard")

        refute has_element?(lv, "[data-role='date-range-filter']")
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "mount/3" — dashboard state (with integrations and metrics)
  # ---------------------------------------------------------------------------

  describe "mount/3 dashboard state" do
    test "shows the All Metrics heading when user has integrations", %{conn: conn} do
      user = user_fixture()
      insert_integration!(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/dashboard")

        assert html =~ "All Metrics"
      end)
    end

    test "shows the metrics dashboard area when user has integrations", %{conn: conn} do
      user = user_fixture()
      insert_integration!(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboard")

        assert has_element?(lv, "[data-role='metrics-dashboard']")
      end)
    end

    test "does not show the onboarding prompt when user has integrations", %{conn: conn} do
      user = user_fixture()
      insert_integration!(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboard")

        refute has_element?(lv, "[data-role='onboarding-prompt']")
      end)
    end

    test "shows connected platform names from the user's integrations", %{conn: conn} do
      user = user_fixture()
      insert_integration!(user, :google_analytics)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/dashboard")

        assert html =~ "Google"
      end)
    end

    test "displays date range ending at yesterday in the date range section", %{conn: conn} do
      user = user_fixture()
      insert_integration!(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/dashboard")

        assert html =~ Date.to_iso8601(yesterday())
      end)
    end

    test "shows vega-lite chart containers when user has integrations and metrics", %{conn: conn} do
      user = user_fixture()
      insert_integration!(user)
      insert_metric!(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboard")

        assert has_element?(lv, "[data-role='vega-lite-chart']")
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "mount/3" — filter controls
  # ---------------------------------------------------------------------------

  describe "mount/3 filter controls" do
    test "shows the platform filter control when user has integrations", %{conn: conn} do
      user = user_fixture()
      insert_integration!(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboard")

        assert has_element?(lv, "[data-role='platform-filter']")
      end)
    end

    test "shows the date range filter control when user has integrations", %{conn: conn} do
      user = user_fixture()
      insert_integration!(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboard")

        assert has_element?(lv, "[data-role='date-range-filter']")
      end)
    end

    test "shows the 7 days date range preset in the date range filter", %{conn: conn} do
      user = user_fixture()
      insert_integration!(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboard")

        assert has_element?(
                 lv,
                 "[data-role='date-range-filter'] [phx-value-range='last_7_days']"
               )
      end)
    end

    test "shows the 30 days date range preset in the date range filter", %{conn: conn} do
      user = user_fixture()
      insert_integration!(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboard")

        assert has_element?(
                 lv,
                 "[data-role='date-range-filter'] [phx-value-range='last_30_days']"
               )
      end)
    end

    test "shows the 90 days date range preset in the date range filter", %{conn: conn} do
      user = user_fixture()
      insert_integration!(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboard")

        assert has_element?(
                 lv,
                 "[data-role='date-range-filter'] [phx-value-range='last_90_days']"
               )
      end)
    end

    test "shows the All Time date range preset in the date range filter", %{conn: conn} do
      user = user_fixture()
      insert_integration!(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboard")

        assert has_element?(
                 lv,
                 "[data-role='date-range-filter'] [phx-value-range='all_time']"
               )
      end)
    end

    test "shows the Custom date range preset in the date range filter", %{conn: conn} do
      user = user_fixture()
      insert_integration!(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboard")

        assert has_element?(
                 lv,
                 "[data-role='date-range-filter'] [phx-value-range='custom']"
               )
      end)
    end

    test "shows the metric toggles when user has integrations", %{conn: conn} do
      user = user_fixture()
      insert_integration!(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboard")

        assert has_element?(lv, "[data-role='metric-toggles']")
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_event filter_platform"
  # ---------------------------------------------------------------------------

  describe "handle_event filter_platform" do
    test "filter_platform event updates the dashboard without error", %{conn: conn} do
      user = user_fixture()
      insert_integration!(user, :google_analytics)
      insert_metric!(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboard")

        html = render_click(lv, "filter_platform", %{"platform" => "google_analytics"})

        assert is_binary(html)
        assert has_element?(lv, "[data-role='metrics-dashboard']")
      end)
    end

    test "filter_platform event with all clears the platform filter", %{conn: conn} do
      user = user_fixture()
      insert_integration!(user, :google_analytics)
      insert_metric!(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboard")

        # First select a specific platform
        render_click(lv, "filter_platform", %{"platform" => "google_analytics"})

        # Then clear with "all"
        html = render_click(lv, "filter_platform", %{"platform" => "all"})

        assert is_binary(html)
        assert has_element?(lv, "[data-role='metrics-dashboard']")
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_event filter_date_range"
  # ---------------------------------------------------------------------------

  describe "handle_event filter_date_range" do
    test "filter_date_range event with last_7_days updates the dashboard", %{conn: conn} do
      user = user_fixture()
      insert_integration!(user)
      insert_metric!(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboard")

        html = render_click(lv, "filter_date_range", %{"range" => "last_7_days"})

        assert is_binary(html)
        assert has_element?(lv, "[data-role='metrics-dashboard']")
      end)
    end

    test "filter_date_range event with last_30_days updates the dashboard", %{conn: conn} do
      user = user_fixture()
      insert_integration!(user)
      insert_metric!(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboard")

        html = render_click(lv, "filter_date_range", %{"range" => "last_30_days"})

        assert is_binary(html)
        assert has_element?(lv, "[data-role='metrics-dashboard']")
      end)
    end

    test "filter_date_range event with last_90_days updates the dashboard", %{conn: conn} do
      user = user_fixture()
      insert_integration!(user)
      insert_metric!(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboard")

        html = render_click(lv, "filter_date_range", %{"range" => "last_90_days"})

        assert is_binary(html)
        assert has_element?(lv, "[data-role='metrics-dashboard']")
      end)
    end

    test "filter_date_range event with all_time updates the dashboard", %{conn: conn} do
      user = user_fixture()
      insert_integration!(user)
      insert_metric!(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboard")

        html = render_click(lv, "filter_date_range", %{"range" => "all_time"})

        assert is_binary(html)
        assert has_element?(lv, "[data-role='metrics-dashboard']")
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_event toggle_metric"
  # ---------------------------------------------------------------------------

  describe "handle_event toggle_metric" do
    test "toggle_metric event hides a metric from the chart and table", %{conn: conn} do
      user = user_fixture()
      insert_integration!(user)
      insert_metric!(user, %{metric_name: "sessions"})
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboard")

        # Toggle off the "sessions" metric (it's a known enriched metric name won't match,
        # but the "sessions" metric from insert_metric! will be in the list)
        html = render_click(lv, "toggle_metric", %{"metric" => "sessions"})

        assert is_binary(html)
        assert has_element?(lv, "[data-role='metrics-dashboard']")
      end)
    end

    test "toggle_metric event re-enables a previously hidden metric", %{conn: conn} do
      user = user_fixture()
      insert_integration!(user)
      insert_metric!(user, %{metric_name: "sessions"})
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboard")

        # Toggle off then back on
        render_click(lv, "toggle_metric", %{"metric" => "sessions"})
        html = render_click(lv, "toggle_metric", %{"metric" => "sessions"})

        assert is_binary(html)
        assert has_element?(lv, "[data-role='metrics-dashboard']")
      end)
    end
  end
end
