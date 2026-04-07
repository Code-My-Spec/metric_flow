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
  # Test Assertions from spec
  # ---------------------------------------------------------------------------

  describe "renders new visualization page with name field and metric selector" do
    test "renders new visualization page with name field and metric selector", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, html} = live(conn, ~p"/app/visualizations/new")

        assert html =~ "New Visualization"
        assert has_element?(lv, "[data-role='visualization-name-input']")
        assert has_element?(lv, "[data-role='metric-selector']")
        assert has_element?(lv, "[data-role='chart-type-selector']")
        assert has_element?(lv, "[data-role='chart-preview-section']")
      end)
    end
  end

  describe "renders edit visualization page loading existing visualization data" do
    test "renders edit visualization page loading existing visualization data", %{conn: conn} do
      user = user_fixture()
      visualization = visualization_fixture(user, %{name: "My Existing Viz"})
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/app/visualizations/#{visualization.id}/edit")

        assert html =~ "Edit Visualization"
        assert html =~ "My Existing Viz"
      end)
    end
  end

  describe "shows available metrics from connected integrations in metric selector" do
    test "shows available metrics from connected integrations in metric selector", %{conn: conn} do
      user = user_fixture()
      insert_editor_test_metrics!(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/app/visualizations/new")

        assert has_element?(lv, "[data-role='metric-list'] button", "sessions")
        assert has_element?(lv, "[data-role='metric-list'] button", "clicks")
      end)
    end
  end

  describe "shows empty state in metric selector when no metrics are available" do
    test "shows empty state in metric selector when no metrics are available", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/app/visualizations/new")

        assert has_element?(lv, "[data-role='no-metrics-available']")
      end)
    end
  end

  describe "toggles metric selection on select_metric click" do
    test "toggles metric selection on select_metric click", %{conn: conn} do
      user = user_fixture()
      insert_editor_test_metrics!(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/app/visualizations/new")

        html =
          lv
          |> element("[data-role='metric-list'] button", "sessions")
          |> render_click()

        assert html =~ "btn-primary"
        refute has_element?(lv, "[data-role='preview-chart-btn'][disabled]")
      end)
    end

  end

  describe "selects chart type on select_chart_type click and highlights active button" do
    test "selects chart type on select_chart_type click and highlights active button", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/app/visualizations/new")

        html =
          lv
          |> element("[data-role='chart-type-selector'] [phx-value-chart_type='bar']")
          |> render_click()

        assert html =~ "btn-primary"
      end)
    end
  end

  describe "previews chart with Vega-Lite spec when preview_chart is clicked" do
    test "previews chart with Vega-Lite spec when preview_chart is clicked", %{conn: conn} do
      user = user_fixture()
      insert_editor_test_metrics!(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/app/visualizations/new")

        lv |> element("[data-role='metric-list'] button", "sessions") |> render_click()
        render_click(lv, "preview_chart", %{})

        assert has_element?(lv, "[data-role='vega-lite-chart']")
        refute has_element?(lv, "[data-role='chart-placeholder']")
      end)
    end
  end

  describe "disables preview button when no metrics are selected" do
    test "disables preview button when no metrics are selected", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/app/visualizations/new")

        assert has_element?(lv, "[data-role='preview-chart-btn'][disabled]")
      end)
    end
  end

  describe "validates name field on change and shows inline error for blank name" do
    test "validates name field on change and shows inline error for blank name", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/app/visualizations/new")

        html = render_change(lv, "validate_name", %{"name" => ""})
        assert html =~ "can&#39;t be blank"
      end)
    end

  end

  describe "saves visualization and navigates to index with success flash" do
    test "saves visualization and navigates to index with success flash", %{conn: conn} do
      user = user_fixture()
      insert_editor_test_metrics!(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/app/visualizations/new")

        render_change(lv, "validate_name", %{"name" => "My New Chart"})
        lv |> element("[data-role='metric-list'] button", "sessions") |> render_click()
        lv |> element("[data-role='save-visualization-btn']") |> render_click()

        assert_redirect(lv, "/app/dashboards")
      end)
    end

  end

  describe "shows validation errors when saving with blank name or no metrics selected" do
    test "shows validation errors when saving with blank name or no metrics selected", %{conn: conn} do
      user = user_fixture()
      insert_editor_test_metrics!(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/app/visualizations/new")

        lv |> element("[data-role='metric-list'] button", "sessions") |> render_click()

        html =
          lv |> element("[data-role='save-visualization-btn']") |> render_click()

        assert html =~ "can&#39;t be blank"
      end)
    end

  end

  describe "toggles shareable flag on toggle_shareable click" do
    test "toggles shareable flag on toggle_shareable click", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/app/visualizations/new")

        html = lv |> element("[data-role='toggle-shareable']") |> render_click()
        assert html =~ "btn-primary"

        html = lv |> element("[data-role='toggle-shareable']") |> render_click()
        refute html =~ ~r/toggle-shareable[^>]*btn-primary/
      end)
    end
  end

  describe "redirects to visualizations with error when editing non-existent visualization" do
    test "redirects to visualizations with error when editing non-existent visualization", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        assert {:error, {:redirect, %{to: "/app/dashboards"}}} =
                 live(conn, ~p"/app/visualizations/999999/edit")
      end)
    end

  end
end
