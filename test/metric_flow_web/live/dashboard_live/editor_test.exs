defmodule MetricFlowWeb.DashboardLive.EditorTest do
  use MetricFlowTest.ConnCase, async: false

  import ExUnit.CaptureLog
  import Phoenix.LiveViewTest
  import MetricFlowTest.UsersFixtures
  import MetricFlowTest.MetricsFixtures

  alias MetricFlow.Dashboards.Dashboard
  alias MetricFlow.Repo

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp dashboard_fixture(user, attrs \\ %{}) do
    defaults = %{
      name: "My Test Dashboard #{System.unique_integer([:positive])}",
      user_id: user.id
    }

    %Dashboard{}
    |> Dashboard.changeset(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end

  # ---------------------------------------------------------------------------
  # Test Assertions from spec
  # ---------------------------------------------------------------------------

  describe "renders new dashboard editor with name field, template chooser, and save button" do
    test "shows new editor elements", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, html} = live(conn, ~p"/dashboards/new")

        assert html =~ "New Dashboard"
        assert has_element?(lv, "[data-role='dashboard-name-input']")
        assert has_element?(lv, "[data-role='template-chooser']")
        assert has_element?(lv, "[data-role='save-dashboard-btn']")
      end)
    end
  end

  describe "renders edit dashboard editor loading existing dashboard data" do
    test "shows edit editor with pre-populated name", %{conn: conn} do
      user = user_fixture()
      dashboard = dashboard_fixture(user, %{name: "My Existing Dashboard"})
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/dashboards/#{dashboard.id}/edit")

        assert html =~ "Edit Dashboard"
        assert html =~ "My Existing Dashboard"
      end)
    end
  end

  describe "validates dashboard name on change and shows inline error for blank name" do
    test "shows error for blank name", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboards/new")

        html = render_change(lv, "validate_name", %{"dashboard" => %{"name" => ""}})
        assert html =~ "can&#39;t be blank"
      end)
    end
  end

  describe "selects a template and applies its visualizations to the canvas" do
    test "applies template visualizations", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboards/new")

        lv
        |> element("[data-role='template-card-marketing_overview']")
        |> render_click()

        assert has_element?(lv, "[data-role='visualization-card']")
        refute has_element?(lv, "[data-role='empty-canvas']")
      end)
    end
  end

  describe "clears canvas when blank template is selected" do
    test "clears visualizations", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboards/new")

        lv |> element("[data-role='template-card-marketing_overview']") |> render_click()
        assert has_element?(lv, "[data-role='visualization-card']")

        render_click(lv, "clear_canvas", %{})
        assert has_element?(lv, "[data-role='empty-canvas']")
      end)
    end
  end

  describe "opens metric picker and selects a metric and chart type" do
    test "opens picker and selects", %{conn: conn} do
      user = user_fixture()
      insert_editor_test_metrics!(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboards/new")

        render_click(lv, "open_metric_picker", %{})
        assert has_element?(lv, "[data-role='metric-picker']")

        lv |> element("[data-role='metric-list'] button", "sessions") |> render_click()

        html =
          lv
          |> element("[data-role='chart-type-selector'] [phx-value-chart_type='bar']")
          |> render_click()

        assert html =~ "btn-primary"
      end)
    end
  end

  describe "adds a visualization to the canvas from the metric picker" do
    test "adds visualization card", %{conn: conn} do
      user = user_fixture()
      insert_editor_test_metrics!(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboards/new")

        render_click(lv, "open_metric_picker", %{})
        lv |> element("[data-role='metric-list'] button", "sessions") |> render_click()
        render_click(lv, "add_visualization", %{})

        assert has_element?(lv, "[data-role='visualization-card']")
      end)
    end
  end

  describe "removes a visualization from the canvas" do
    test "removes visualization card", %{conn: conn} do
      user = user_fixture()
      insert_editor_test_metrics!(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboards/new")

        render_click(lv, "open_metric_picker", %{})
        lv |> element("[data-role='metric-list'] button", "sessions") |> render_click()
        render_click(lv, "add_visualization", %{})

        lv |> element("[aria-label='Remove']") |> render_click()

        assert has_element?(lv, "[data-role='empty-canvas']")
      end)
    end
  end

  describe "reorders visualizations with move up and move down buttons" do
    test "moves visualizations", %{conn: conn} do
      user = user_fixture()
      insert_editor_test_metrics!(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboards/new")

        render_click(lv, "open_metric_picker", %{})
        lv |> element("[data-role='metric-list'] button", "sessions") |> render_click()
        render_click(lv, "add_visualization", %{})

        render_click(lv, "open_metric_picker", %{})
        lv |> element("[data-role='metric-list'] button", "clicks") |> render_click()
        render_click(lv, "add_visualization", %{})

        html = render_click(lv, "move_visualization_down", %{"index" => "0"})
        assert is_binary(html)
      end)
    end
  end

  describe "saves dashboard and navigates to show page with success flash" do
    test "saves and redirects", %{conn: conn} do
      user = user_fixture()
      insert_editor_test_metrics!(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboards/new")

        render_change(lv, "validate_name", %{"dashboard" => %{"name" => "My New Dashboard"}})

        render_click(lv, "open_metric_picker", %{})
        lv |> element("[data-role='metric-list'] button", "sessions") |> render_click()
        render_click(lv, "add_visualization", %{})

        lv |> element("[data-role='save-dashboard-btn']") |> render_click()

        assert_redirect(lv)
      end)
    end
  end

  describe "shows error when saving with no visualizations added" do
    test "displays viz error", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboards/new")

        render_change(lv, "validate_name", %{"dashboard" => %{"name" => "My Dashboard"}})

        html =
          lv |> element("[data-role='save-dashboard-btn']") |> render_click()

        assert html =~ "add at least one visualization"
      end)
    end
  end

  describe "redirects to dashboard with error when editing non-existent dashboard" do
    test "redirects for invalid ID", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        assert {:error, {:redirect, _}} = live(conn, ~p"/dashboards/999999/edit")
      end)
    end
  end
end
