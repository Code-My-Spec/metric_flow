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

  defp valid_dashboard_attrs do
    %{"name" => "My New Dashboard"}
  end

  defp invalid_dashboard_attrs do
    %{"name" => ""}
  end

  # ---------------------------------------------------------------------------
  # describe "authentication"
  # ---------------------------------------------------------------------------

  describe "authentication" do
    test "redirects unauthenticated users to /users/log-in on new route", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} =
               live(conn, ~p"/dashboards/new")
    end

    test "redirects unauthenticated users to /users/log-in on edit route", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} =
               live(conn, ~p"/dashboards/1/edit")
    end
  end

  # ---------------------------------------------------------------------------
  # describe "mount/3 new route"
  # ---------------------------------------------------------------------------

  describe "mount/3 new route" do
    test "renders the new dashboard page with 'New Dashboard' heading", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/dashboards/new")

        assert html =~ "New Dashboard"
      end)
    end

    test "renders the dashboard name input field", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboards/new")

        assert has_element?(lv, "[data-role='dashboard-name-input']")
      end)
    end

    test "renders the empty canvas state when no visualizations exist", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboards/new")

        assert has_element?(lv, "[data-role='empty-canvas']")
      end)
    end

    test "renders the template chooser when canvas is empty", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboards/new")

        assert has_element?(lv, "[data-role='template-chooser']")
      end)
    end

    test "renders the add visualization button", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboards/new")

        assert has_element?(lv, "[data-role='add-visualization-btn']")
      end)
    end

    test "does not render the metric picker panel on initial mount", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboards/new")

        refute has_element?(lv, "[data-role='metric-picker']")
      end)
    end

    test "renders the save dashboard button", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/dashboards/new")

        assert html =~ "Save Dashboard"
      end)
    end

    test "renders a cancel link back to /dashboards", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboards/new")

        assert has_element?(lv, "a[href='/dashboards']", "Cancel")
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "mount/3 edit route"
  # ---------------------------------------------------------------------------

  describe "mount/3 edit route" do
    test "renders the edit dashboard page with 'Edit Dashboard' heading", %{conn: conn} do
      user = user_fixture()
      dashboard = dashboard_fixture(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/dashboards/#{dashboard.id}/edit")

        assert html =~ "Edit Dashboard"
      end)
    end

    test "pre-populates the dashboard name field with the existing dashboard name", %{conn: conn} do
      user = user_fixture()
      dashboard = dashboard_fixture(user, %{name: "Existing Dashboard Name"})
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/dashboards/#{dashboard.id}/edit")

        assert html =~ "Existing Dashboard Name"
      end)
    end

    test "redirects to /dashboards when the dashboard does not belong to the current account", %{
      conn: conn
    } do
      owner = user_fixture()
      other_user = user_fixture()
      dashboard = dashboard_fixture(owner)
      conn = log_in_user(conn, other_user)

      capture_log(fn ->
        assert {:error, {:redirect, %{to: "/dashboards"}}} =
                 live(conn, ~p"/dashboards/#{dashboard.id}/edit")
      end)
    end

    test "redirects to /dashboards when the dashboard id does not exist", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        assert {:error, {:redirect, %{to: "/dashboards"}}} =
                 live(conn, ~p"/dashboards/999999/edit")
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_event validate_name"
  # ---------------------------------------------------------------------------

  describe "handle_event validate_name" do
    test "shows inline error when dashboard name is blank", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboards/new")

        html =
          lv
          |> form("form", %{"dashboard" => invalid_dashboard_attrs()})
          |> render_change()

        assert html =~ "can&#39;t be blank"
      end)
    end

    test "clears inline error when a valid name is typed after a blank submission", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboards/new")

        lv
        |> form("form", %{"dashboard" => invalid_dashboard_attrs()})
        |> render_change()

        html =
          lv
          |> form("form", %{"dashboard" => valid_dashboard_attrs()})
          |> render_change()

        refute html =~ "can&#39;t be blank"
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_event open_metric_picker"
  # ---------------------------------------------------------------------------

  describe "handle_event open_metric_picker" do
    test "shows the metric picker panel after clicking add visualization", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboards/new")

        lv
        |> element("[data-role='add-visualization-btn']")
        |> render_click()

        assert has_element?(lv, "[data-role='metric-picker']")
      end)
    end

    test "shows the metric list inside the picker after opening", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboards/new")

        lv
        |> element("[data-role='add-visualization-btn']")
        |> render_click()

        assert has_element?(lv, "[data-role='metric-list']")
      end)
    end

    test "shows the chart type selector inside the picker after opening", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboards/new")

        lv
        |> element("[data-role='add-visualization-btn']")
        |> render_click()

        assert has_element?(lv, "[data-role='chart-type-selector']")
      end)
    end

    test "the confirm add button is disabled when no metric is selected", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboards/new")

        lv
        |> element("[data-role='add-visualization-btn']")
        |> render_click()

        assert has_element?(lv, "[data-role='confirm-add-btn'][disabled]")
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_event close_metric_picker"
  # ---------------------------------------------------------------------------

  describe "handle_event close_metric_picker" do
    test "hides the metric picker panel after closing", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboards/new")

        lv
        |> element("[data-role='add-visualization-btn']")
        |> render_click()

        lv
        |> element("[phx-click='close_metric_picker']")
        |> render_click()

        refute has_element?(lv, "[data-role='metric-picker']")
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_event select_metric"
  # ---------------------------------------------------------------------------

  describe "handle_event select_metric" do
    test "enables the confirm add button after a metric is selected", %{conn: conn} do
      user = user_fixture()
      insert_editor_test_metrics!(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboards/new")

        lv
        |> element("[data-role='add-visualization-btn']")
        |> render_click()

        lv
        |> element("[data-role='metric-list'] button", "sessions")
        |> render_click()

        refute has_element?(lv, "[data-role='confirm-add-btn'][disabled]")
      end)
    end

    test "highlights the selected metric with btn-primary styling", %{conn: conn} do
      user = user_fixture()
      insert_editor_test_metrics!(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboards/new")

        lv
        |> element("[data-role='add-visualization-btn']")
        |> render_click()

        html =
          lv
          |> element("[data-role='metric-list'] button", "sessions")
          |> render_click()

        assert html =~ "btn-primary"
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_event select_chart_type"
  # ---------------------------------------------------------------------------

  describe "handle_event select_chart_type" do
    test "updates the active chart type to bar", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboards/new")

        lv
        |> element("[data-role='add-visualization-btn']")
        |> render_click()

        html =
          lv
          |> element("[data-role='chart-type-selector'] [phx-value-chart_type='bar']")
          |> render_click()

        assert html =~ "btn-primary"
      end)
    end

    test "updates the active chart type to area", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboards/new")

        lv
        |> element("[data-role='add-visualization-btn']")
        |> render_click()

        html =
          lv
          |> element("[data-role='chart-type-selector'] [phx-value-chart_type='area']")
          |> render_click()

        assert html =~ "btn-primary"
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_event add_visualization"
  # ---------------------------------------------------------------------------

  describe "handle_event add_visualization" do
    test "adds a visualization card to the canvas after selecting a metric and confirming", %{
      conn: conn
    } do
      user = user_fixture()
      insert_editor_test_metrics!(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboards/new")

        lv
        |> element("[data-role='add-visualization-btn']")
        |> render_click()

        lv
        |> element("[data-role='metric-list'] button", "sessions")
        |> render_click()

        lv
        |> element("[data-role='confirm-add-btn']")
        |> render_click()

        assert has_element?(lv, "[data-role='visualization-card']")
      end)
    end

    test "closes the metric picker after adding a visualization", %{conn: conn} do
      user = user_fixture()
      insert_editor_test_metrics!(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboards/new")

        lv
        |> element("[data-role='add-visualization-btn']")
        |> render_click()

        lv
        |> element("[data-role='metric-list'] button", "sessions")
        |> render_click()

        lv
        |> element("[data-role='confirm-add-btn']")
        |> render_click()

        refute has_element?(lv, "[data-role='metric-picker']")
      end)
    end

    test "hides the empty canvas state after the first visualization is added", %{conn: conn} do
      user = user_fixture()
      insert_editor_test_metrics!(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboards/new")

        lv
        |> element("[data-role='add-visualization-btn']")
        |> render_click()

        lv
        |> element("[data-role='metric-list'] button", "sessions")
        |> render_click()

        lv
        |> element("[data-role='confirm-add-btn']")
        |> render_click()

        refute has_element?(lv, "[data-role='empty-canvas']")
      end)
    end

    test "does not add a visualization when no metric is selected", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboards/new")

        lv
        |> element("[data-role='add-visualization-btn']")
        |> render_click()

        render_click(lv, "add_visualization", %{})

        refute has_element?(lv, "[data-role='visualization-card']")
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_event remove_visualization"
  # ---------------------------------------------------------------------------

  describe "handle_event remove_visualization" do
    test "removes the visualization card from the canvas", %{conn: conn} do
      user = user_fixture()
      insert_editor_test_metrics!(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboards/new")

        lv |> element("[data-role='add-visualization-btn']") |> render_click()
        lv |> element("[data-role='metric-list'] button", "sessions") |> render_click()
        lv |> element("[data-role='confirm-add-btn']") |> render_click()

        assert has_element?(lv, "[data-role='visualization-card']")

        lv
        |> element("[data-role='visualization-card'] [phx-click='remove_visualization']")
        |> render_click()

        refute has_element?(lv, "[data-role='visualization-card']")
      end)
    end

    test "shows the empty canvas state after removing the last visualization", %{conn: conn} do
      user = user_fixture()
      insert_editor_test_metrics!(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboards/new")

        lv |> element("[data-role='add-visualization-btn']") |> render_click()
        lv |> element("[data-role='metric-list'] button", "sessions") |> render_click()
        lv |> element("[data-role='confirm-add-btn']") |> render_click()

        lv
        |> element("[data-role='visualization-card'] [phx-click='remove_visualization']")
        |> render_click()

        assert has_element?(lv, "[data-role='empty-canvas']")
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_event move_visualization_up"
  # ---------------------------------------------------------------------------

  describe "handle_event move_visualization_up" do
    test "moves a visualization up one position in the canvas", %{conn: conn} do
      user = user_fixture()
      insert_editor_test_metrics!(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboards/new")

        lv |> element("[data-role='add-visualization-btn']") |> render_click()
        lv |> element("[data-role='metric-list'] button", "sessions") |> render_click()
        lv |> element("[data-role='confirm-add-btn']") |> render_click()

        lv |> element("[data-role='add-visualization-btn']") |> render_click()
        lv |> element("[data-role='metric-list'] button", "clicks") |> render_click()
        lv |> element("[data-role='confirm-add-btn']") |> render_click()

        html_before = render(lv)

        lv
        |> element(
          "[data-role='visualization-canvas'] [data-role='visualization-card']:last-child [phx-click='move_visualization_up']"
        )
        |> render_click()

        html_after = render(lv)

        assert html_after != html_before
      end)
    end

    test "is a no-op when attempting to move the first visualization up", %{conn: conn} do
      user = user_fixture()
      insert_editor_test_metrics!(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboards/new")

        lv |> element("[data-role='add-visualization-btn']") |> render_click()
        lv |> element("[data-role='metric-list'] button", "sessions") |> render_click()
        lv |> element("[data-role='confirm-add-btn']") |> render_click()

        html_before = render(lv)

        lv
        |> element(
          "[data-role='visualization-canvas'] [data-role='visualization-card']:first-child [phx-click='move_visualization_up']"
        )
        |> render_click()

        html_after = render(lv)

        assert html_after == html_before
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_event move_visualization_down"
  # ---------------------------------------------------------------------------

  describe "handle_event move_visualization_down" do
    test "moves a visualization down one position in the canvas", %{conn: conn} do
      user = user_fixture()
      insert_editor_test_metrics!(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboards/new")

        lv |> element("[data-role='add-visualization-btn']") |> render_click()
        lv |> element("[data-role='metric-list'] button", "sessions") |> render_click()
        lv |> element("[data-role='confirm-add-btn']") |> render_click()

        lv |> element("[data-role='add-visualization-btn']") |> render_click()
        lv |> element("[data-role='metric-list'] button", "clicks") |> render_click()
        lv |> element("[data-role='confirm-add-btn']") |> render_click()

        html_before = render(lv)

        lv
        |> element(
          "[data-role='visualization-canvas'] [data-role='visualization-card']:first-child [phx-click='move_visualization_down']"
        )
        |> render_click()

        html_after = render(lv)

        assert html_after != html_before
      end)
    end

    test "is a no-op when attempting to move the last visualization down", %{conn: conn} do
      user = user_fixture()
      insert_editor_test_metrics!(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboards/new")

        lv |> element("[data-role='add-visualization-btn']") |> render_click()
        lv |> element("[data-role='metric-list'] button", "sessions") |> render_click()
        lv |> element("[data-role='confirm-add-btn']") |> render_click()

        html_before = render(lv)

        lv
        |> element(
          "[data-role='visualization-canvas'] [data-role='visualization-card']:last-child [phx-click='move_visualization_down']"
        )
        |> render_click()

        html_after = render(lv)

        assert html_after == html_before
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_event select_template"
  # ---------------------------------------------------------------------------

  describe "handle_event select_template" do
    test "populates the canvas with visualizations from the selected template", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboards/new")

        lv
        |> element("[phx-click='select_template'][phx-value-template='marketing_overview']")
        |> render_click()

        assert has_element?(lv, "[data-role='visualization-card']")
      end)
    end

    test "replaces existing visualizations when a template is selected", %{conn: conn} do
      user = user_fixture()
      insert_editor_test_metrics!(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboards/new")

        lv |> element("[data-role='add-visualization-btn']") |> render_click()
        lv |> element("[data-role='metric-list'] button", "sessions") |> render_click()
        lv |> element("[data-role='confirm-add-btn']") |> render_click()

        render_click(lv, "select_template", %{"template" => "financial_summary"})

        refute render(lv) =~ "sessions"
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_event clear_canvas"
  # ---------------------------------------------------------------------------

  describe "handle_event clear_canvas" do
    test "clears all visualizations from the canvas", %{conn: conn} do
      user = user_fixture()
      insert_editor_test_metrics!(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboards/new")

        lv |> element("[data-role='add-visualization-btn']") |> render_click()
        lv |> element("[data-role='metric-list'] button", "sessions") |> render_click()
        lv |> element("[data-role='confirm-add-btn']") |> render_click()

        render_click(lv, "clear_canvas", %{})

        refute has_element?(lv, "[data-role='visualization-card']")
      end)
    end

    test "shows the empty canvas state after clearing", %{conn: conn} do
      user = user_fixture()
      insert_editor_test_metrics!(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboards/new")

        lv |> element("[data-role='add-visualization-btn']") |> render_click()
        lv |> element("[data-role='metric-list'] button", "sessions") |> render_click()
        lv |> element("[data-role='confirm-add-btn']") |> render_click()

        render_click(lv, "clear_canvas", %{})

        assert has_element?(lv, "[data-role='empty-canvas']")
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_event save_dashboard"
  # ---------------------------------------------------------------------------

  describe "handle_event save_dashboard" do
    test "redirects to the dashboard show page on successful create", %{conn: conn} do
      user = user_fixture()
      insert_editor_test_metrics!(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboards/new")

        lv |> element("[data-role='add-visualization-btn']") |> render_click()
        lv |> element("[data-role='metric-list'] button", "sessions") |> render_click()
        lv |> element("[data-role='confirm-add-btn']") |> render_click()

        lv
        |> form("form", %{"dashboard" => valid_dashboard_attrs()})
        |> render_change()

        lv
        |> element("button", "Save Dashboard")
        |> render_click()

        {path, _flash} = assert_redirect(lv)
        assert path =~ ~r"/dashboards/\d+"
      end)
    end

    test "shows validation error when saving with a blank dashboard name", %{conn: conn} do
      user = user_fixture()
      insert_editor_test_metrics!(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboards/new")

        lv |> element("[data-role='add-visualization-btn']") |> render_click()
        lv |> element("[data-role='metric-list'] button", "sessions") |> render_click()
        lv |> element("[data-role='confirm-add-btn']") |> render_click()

        lv
        |> form("form", %{"dashboard" => invalid_dashboard_attrs()})
        |> render_change()

        html =
          lv
          |> element("button", "Save Dashboard")
          |> render_click()

        assert html =~ "can&#39;t be blank"
      end)
    end

    test "shows validation error when saving with no visualizations", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboards/new")

        lv
        |> form("form", %{"dashboard" => valid_dashboard_attrs()})
        |> render_change()

        html =
          lv
          |> element("button", "Save Dashboard")
          |> render_click()

        assert html =~ "at least one visualization"
      end)
    end

    test "redirects to the dashboard show page on successful update", %{conn: conn} do
      user = user_fixture()
      insert_editor_test_metrics!(user)
      dashboard = dashboard_fixture(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboards/#{dashboard.id}/edit")

        lv |> element("[data-role='add-visualization-btn']") |> render_click()
        lv |> element("[data-role='metric-list'] button", "sessions") |> render_click()
        lv |> element("[data-role='confirm-add-btn']") |> render_click()

        lv
        |> element("button", "Save Dashboard")
        |> render_click()

        assert_redirect(lv, ~p"/dashboards/#{dashboard.id}")
      end)
    end
  end
end
