defmodule MetricFlowWeb.ReportLive.IndexTest do
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
      name: "Test Report #{System.unique_integer([:positive])}",
      user_id: user.id,
      vega_spec: %{"chart_type" => "custom"},
      shareable: false
    }

    %Visualization{}
    |> Visualization.changeset(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end

  # ---------------------------------------------------------------------------
  # describe "renders reports index page with header and New Report button"
  # ---------------------------------------------------------------------------

  describe "renders reports index page with header and New Report button" do
    test "renders reports index page with header and New Report button", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, html} = live(conn, ~p"/app/reports")

        assert html =~ "Reports"
        assert has_element?(lv, "[data-role='new-report-btn'][href='/reports/new']")
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "shows available metric badges when metrics exist"
  # ---------------------------------------------------------------------------

  describe "shows available metric badges when metrics exist" do
    test "shows available metric badges when metrics exist", %{conn: conn} do
      user = user_fixture()
      insert_metric!(user, %{metric_name: "sessions"})
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/app/reports")

        assert has_element?(lv, "[data-role='metric-summary']")
        assert has_element?(lv, "[data-role='metric-badge']")
        assert render(lv) =~ "sessions"
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "displays saved report cards with name and actions"
  # ---------------------------------------------------------------------------

  describe "displays saved report cards with name and actions" do
    test "displays saved report cards with name and actions", %{conn: conn} do
      user = user_fixture()
      report = visualization_fixture(user, %{name: "Q1 Revenue Summary", shareable: true})
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, html} = live(conn, ~p"/app/reports")

        assert html =~ "Q1 Revenue Summary"
        assert has_element?(lv, "[data-role='report-card'][data-report-id='#{report.id}']")
        assert has_element?(lv, "[data-role='view-report-#{report.id}']")
        assert has_element?(lv, "[data-role='delete-report-#{report.id}']")
        assert html =~ "Shareable"
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "shows empty state when no saved reports exist"
  # ---------------------------------------------------------------------------

  describe "shows empty state when no saved reports exist" do
    test "shows empty state when no saved reports exist", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/app/reports")

        assert has_element?(lv, "[data-role='empty-reports']")
        assert has_element?(lv, "[data-role='empty-reports'] a[href='/reports/new']")
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "shows delete confirmation inline when Delete is clicked"
  # ---------------------------------------------------------------------------

  describe "shows delete confirmation inline when Delete is clicked" do
    test "shows delete confirmation inline when Delete is clicked", %{conn: conn} do
      user = user_fixture()
      report = visualization_fixture(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/app/reports")

        render_click(lv, "delete", %{"id" => to_string(report.id)})

        assert has_element?(lv, "[data-role='delete-confirm-#{report.id}']")
        assert has_element?(lv, "[data-role='confirm-delete-#{report.id}']")
        assert has_element?(lv, "[data-role='cancel-delete']")
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "deletes report and shows success flash on confirm"
  # ---------------------------------------------------------------------------

  describe "deletes report and shows success flash on confirm" do
    test "deletes report and shows success flash on confirm", %{conn: conn} do
      user = user_fixture()
      report = visualization_fixture(user, %{name: "Expendable Report"})
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/app/reports")

        render_click(lv, "delete", %{"id" => to_string(report.id)})
        html = render_click(lv, "confirm_delete", %{"id" => to_string(report.id)})

        assert html =~ "Report deleted."
        refute has_element?(lv, "[data-role='report-card'][data-report-id='#{report.id}']")
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "cancels delete confirmation without modifying data"
  # ---------------------------------------------------------------------------

  describe "cancels delete confirmation without modifying data" do
    test "cancels delete confirmation without modifying data", %{conn: conn} do
      user = user_fixture()
      report = visualization_fixture(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/app/reports")

        render_click(lv, "delete", %{"id" => to_string(report.id)})
        assert has_element?(lv, "[data-role='delete-confirm-#{report.id}']")

        render_click(lv, "cancel_delete", %{})

        refute has_element?(lv, "[data-role='delete-confirm-#{report.id}']")
        assert has_element?(lv, "[data-role='report-card'][data-report-id='#{report.id}']")
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "renders new report page with AI and manual creation options"
  # ---------------------------------------------------------------------------

  describe "renders new report page with AI and manual creation options" do
    test "renders new report page with AI and manual creation options", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, html} = live(conn, ~p"/app/reports/new")

        assert html =~ "New Report"
        assert has_element?(lv, "[data-role='report-option-ai']")
        assert has_element?(lv, "[data-role='report-option-manual']")
        assert has_element?(lv, "[data-role='report-option-ai'] a[href='/reports/generate']")
        assert has_element?(lv, "[data-role='report-option-manual'] a[href='/visualizations/new']")
      end)
    end
  end
end
