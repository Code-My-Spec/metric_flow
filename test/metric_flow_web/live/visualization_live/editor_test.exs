defmodule MetricFlowWeb.VisualizationLive.EditorTest do
  use MetricFlowTest.ConnCase, async: false

  import ExUnit.CaptureLog
  import Phoenix.LiveViewTest
  import MetricFlowTest.UsersFixtures
  import MetricFlowTest.MetricsFixtures

  alias MetricFlow.Dashboards.Visualization
  alias MetricFlow.Repo

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp visualization_fixture(user, attrs \\ %{}) do
    defaults = %{
      name: "My Test Visualization #{System.unique_integer([:positive])}",
      user_id: user.id,
      vega_spec: %{"$schema" => "https://vega.github.io/schema/vega-lite/v5.json"},
      shareable: false
    }

    %Visualization{}
    |> Visualization.changeset(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end

  # ---------------------------------------------------------------------------
  # describe "authentication"
  # ---------------------------------------------------------------------------

  describe "authentication" do
    test "redirects unauthenticated users to /users/log-in on new route", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} =
               live(conn, ~p"/visualizations/new")
    end

    test "redirects unauthenticated users to /users/log-in on edit route", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} =
               live(conn, ~p"/visualizations/1/edit")
    end
  end

  # ---------------------------------------------------------------------------
  # describe "mount/3 new route"
  # ---------------------------------------------------------------------------

  describe "mount/3 new route" do
    test "renders the new visualization page with 'New Visualization' heading", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/visualizations/new")

        assert html =~ "New Visualization"
      end)
    end

    test "renders the visualization name input field", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/visualizations/new")

        assert has_element?(lv, "[data-role='visualization-name-input']")
      end)
    end

    test "renders the metric selector section", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/visualizations/new")

        assert has_element?(lv, "[data-role='metric-selector']")
      end)
    end

    test "renders the chart type selector section", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/visualizations/new")

        assert has_element?(lv, "[data-role='chart-type-selector']")
      end)
    end

    test "renders the chart preview section", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/visualizations/new")

        assert has_element?(lv, "[data-role='chart-preview-section']")
      end)
    end

    test "renders the chart placeholder when no preview exists", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/visualizations/new")

        assert has_element?(lv, "[data-role='chart-placeholder']")
      end)
    end

    test "renders the preview chart button disabled when no metric is selected", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/visualizations/new")

        assert has_element?(lv, "[data-role='preview-chart-btn'][disabled]")
      end)
    end

    test "renders the Save Visualization button", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/visualizations/new")

        assert html =~ "Save Visualization"
      end)
    end

    test "renders a cancel link back to /visualizations", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/visualizations/new")

        assert has_element?(lv, "a[href='/dashboards']", "Cancel")
      end)
    end

    test "renders the toggle shareable button", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/visualizations/new")

        assert has_element?(lv, "[data-role='toggle-shareable']")
      end)
    end

    test "shows no-metrics-available message when user has no metrics", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/visualizations/new")

        assert has_element?(lv, "[data-role='no-metrics-available']")
      end)
    end

    test "shows metric buttons when user has metrics", %{conn: conn} do
      user = user_fixture()
      insert_editor_test_metrics!(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/visualizations/new")

        assert has_element?(lv, "[data-role='metric-list'] button", "sessions")
        assert has_element?(lv, "[data-role='metric-list'] button", "clicks")
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "mount/3 edit route"
  # ---------------------------------------------------------------------------

  describe "mount/3 edit route" do
    test "renders the edit visualization page with 'Edit Visualization' heading", %{conn: conn} do
      user = user_fixture()
      visualization = visualization_fixture(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/visualizations/#{visualization.id}/edit")

        assert html =~ "Edit Visualization"
      end)
    end

    test "pre-populates the name field with the existing visualization name", %{conn: conn} do
      user = user_fixture()
      visualization = visualization_fixture(user, %{name: "My Existing Visualization"})
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/visualizations/#{visualization.id}/edit")

        assert html =~ "My Existing Visualization"
      end)
    end

    test "redirects to /visualizations when the visualization does not belong to the user", %{
      conn: conn
    } do
      owner = user_fixture()
      other_user = user_fixture()
      visualization = visualization_fixture(owner)
      conn = log_in_user(conn, other_user)

      capture_log(fn ->
        assert {:error, {:redirect, %{to: "/dashboards"}}} =
                 live(conn, ~p"/visualizations/#{visualization.id}/edit")
      end)
    end

    test "redirects to /visualizations when the visualization id does not exist", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        assert {:error, {:redirect, %{to: "/dashboards"}}} =
                 live(conn, ~p"/visualizations/999999/edit")
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_event validate_name"
  # ---------------------------------------------------------------------------

  describe "handle_event validate_name" do
    test "shows inline error when visualization name is blank", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/visualizations/new")

        html = render_change(lv, "validate_name", %{"name" => ""})

        assert html =~ "can&#39;t be blank"
      end)
    end

    test "shows inline error when name exceeds 255 characters", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/visualizations/new")

        long_name = String.duplicate("a", 256)
        html = render_change(lv, "validate_name", %{"name" => long_name})

        assert html =~ "should be at most 255 character"
      end)
    end

    test "clears inline error when a valid name is typed after a blank submission", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/visualizations/new")

        render_change(lv, "validate_name", %{"name" => ""})
        html = render_change(lv, "validate_name", %{"name" => "Valid Name"})

        refute html =~ "can&#39;t be blank"
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_event select_metric"
  # ---------------------------------------------------------------------------

  describe "handle_event select_metric" do
    test "highlights the selected metric with btn-primary styling", %{conn: conn} do
      user = user_fixture()
      insert_editor_test_metrics!(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/visualizations/new")

        html =
          lv
          |> element("[data-role='metric-list'] button", "sessions")
          |> render_click()

        assert html =~ "btn-primary"
      end)
    end

    test "enables the preview chart button after a metric is selected", %{conn: conn} do
      user = user_fixture()
      insert_editor_test_metrics!(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/visualizations/new")

        lv
        |> element("[data-role='metric-list'] button", "sessions")
        |> render_click()

        refute has_element?(lv, "[data-role='preview-chart-btn'][disabled]")
      end)
    end

    test "resets chart preview to nil when a new metric is selected", %{conn: conn} do
      user = user_fixture()
      insert_editor_test_metrics!(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/visualizations/new")

        lv
        |> element("[data-role='metric-list'] button", "sessions")
        |> render_click()

        render_click(lv, "preview_chart", %{})

        lv
        |> element("[data-role='metric-list'] button", "clicks")
        |> render_click()

        assert has_element?(lv, "[data-role='chart-placeholder']")
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_event select_chart_type"
  # ---------------------------------------------------------------------------

  describe "handle_event select_chart_type" do
    test "highlights the selected chart type bar with btn-primary styling", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/visualizations/new")

        html =
          lv
          |> element("[data-role='chart-type-selector'] [phx-value-chart_type='bar']")
          |> render_click()

        assert html =~ "btn-primary"
      end)
    end

    test "highlights the selected chart type area with btn-primary styling", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/visualizations/new")

        html =
          lv
          |> element("[data-role='chart-type-selector'] [phx-value-chart_type='area']")
          |> render_click()

        assert html =~ "btn-primary"
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_event preview_chart"
  # ---------------------------------------------------------------------------

  describe "handle_event preview_chart" do
    test "shows the vega-lite chart container after previewing", %{conn: conn} do
      user = user_fixture()
      insert_editor_test_metrics!(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/visualizations/new")

        lv
        |> element("[data-role='metric-list'] button", "sessions")
        |> render_click()

        render_click(lv, "preview_chart", %{})

        assert has_element?(lv, "[data-role='vega-lite-chart']")
        refute has_element?(lv, "[data-role='chart-placeholder']")
      end)
    end

    test "is a no-op when no metric is selected", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/visualizations/new")

        render_click(lv, "preview_chart", %{})

        assert has_element?(lv, "[data-role='chart-placeholder']")
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_event toggle_shareable"
  # ---------------------------------------------------------------------------

  describe "handle_event toggle_shareable" do
    test "toggles shareable on when clicked", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/visualizations/new")

        html =
          lv
          |> element("[data-role='toggle-shareable']")
          |> render_click()

        assert html =~ "btn-primary"
      end)
    end

    test "toggles shareable off when clicked twice", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/visualizations/new")

        lv |> element("[data-role='toggle-shareable']") |> render_click()

        html = lv |> element("[data-role='toggle-shareable']") |> render_click()

        refute html =~ ~r/toggle-shareable[^>]*btn-primary/
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_event save_visualization"
  # ---------------------------------------------------------------------------

  describe "handle_event save_visualization" do
    test "redirects to /visualizations with success flash on successful create", %{conn: conn} do
      user = user_fixture()
      insert_editor_test_metrics!(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/visualizations/new")

        render_change(lv, "validate_name", %{"name" => "My New Chart"})

        lv
        |> element("[data-role='metric-list'] button", "sessions")
        |> render_click()

        lv
        |> element("[data-role='save-visualization-btn']")
        |> render_click()

        assert_redirect(lv, "/dashboards")
      end)
    end

    test "shows error when saving with a blank name", %{conn: conn} do
      user = user_fixture()
      insert_editor_test_metrics!(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/visualizations/new")

        lv
        |> element("[data-role='metric-list'] button", "sessions")
        |> render_click()

        html =
          lv
          |> element("[data-role='save-visualization-btn']")
          |> render_click()

        assert html =~ "can&#39;t be blank"
      end)
    end

    test "shows error flash when saving with no metric selected", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/visualizations/new")

        render_change(lv, "validate_name", %{"name" => "My Chart"})

        html =
          lv
          |> element("[data-role='save-visualization-btn']")
          |> render_click()

        assert html =~ "select a metric"
      end)
    end

    test "redirects to /visualizations on successful update", %{conn: conn} do
      user = user_fixture()
      insert_editor_test_metrics!(user)
      visualization = visualization_fixture(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/visualizations/#{visualization.id}/edit")

        render_change(lv, "validate_name", %{"name" => "Updated Name"})

        lv
        |> element("[data-role='metric-list'] button", "sessions")
        |> render_click()

        lv
        |> element("[data-role='save-visualization-btn']")
        |> render_click()

        assert_redirect(lv, "/dashboards")
      end)
    end
  end
end
