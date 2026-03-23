defmodule MetricFlowWeb.ReportLive.IndexTest do
  use MetricFlowTest.ConnCase, async: false

  import ExUnit.CaptureLog
  import Phoenix.LiveViewTest
  import MetricFlowTest.UsersFixtures

  # ---------------------------------------------------------------------------
  # describe "authentication"
  # ---------------------------------------------------------------------------

  describe "authentication" do
    test "redirects unauthenticated users to /users/log-in on the index route", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} =
               live(conn, ~p"/reports")
    end

    test "redirects unauthenticated users to /users/log-in on the new route", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} =
               live(conn, ~p"/reports/new")
    end
  end

  # ---------------------------------------------------------------------------
  # describe "mount/3"
  # ---------------------------------------------------------------------------

  describe "mount/3" do
    test "renders the reports index page for an authenticated user", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/reports")

        assert is_binary(html)
      end)
    end

    test "shows the 'Reports' page heading", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/reports")

        assert html =~ "Reports"
      end)
    end

    test "shows a link to create a new report", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/reports")

        assert has_element?(lv, "[data-role='new-report-btn'][href='/reports/new']")
      end)
    end

    test "shows the reports list section", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/reports")

        assert has_element?(lv, "[data-role='reports-list']")
      end)
    end

    test "shows the empty state when the user has no reports", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/reports")

        assert has_element?(lv, "[data-role='empty-reports']")
      end)
    end

    test "shows a link to create the first report from the empty state", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/reports")

        assert has_element?(lv, "[data-role='empty-reports'] a[href='/reports/new']")
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "mount/3 new route"
  # ---------------------------------------------------------------------------

  describe "mount/3 new route" do
    test "renders the new report page for an authenticated user", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/reports/new")

        assert is_binary(html)
      end)
    end

    test "shows a 'New Report' heading on the new report page", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/reports/new")

        assert html =~ "New Report"
      end)
    end

    test "shows a cancel link back to /reports on the new report page", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/reports/new")

        assert has_element?(lv, "a[href='/reports']")
      end)
    end
  end
end
