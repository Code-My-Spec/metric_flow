defmodule MetricFlowWeb.DashboardLive.IndexTest do
  use MetricFlowTest.ConnCase, async: false

  import ExUnit.CaptureLog
  import Phoenix.LiveViewTest
  import MetricFlowTest.UsersFixtures

  alias MetricFlow.Dashboards.Dashboard
  alias MetricFlow.Repo

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp dashboard_fixture(user, attrs \\ %{}) do
    defaults = %{
      name: "My Dashboard #{System.unique_integer([:positive])}",
      user_id: user.id,
      built_in: false
    }

    %Dashboard{}
    |> Dashboard.changeset(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end

  defp canned_dashboard_fixture(user, attrs \\ %{}) do
    defaults = %{
      name: "Canned Dashboard #{System.unique_integer([:positive])}",
      user_id: user.id,
      built_in: true
    }

    %Dashboard{}
    |> Dashboard.changeset(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end

  # ---------------------------------------------------------------------------
  # Test Assertions from spec
  # ---------------------------------------------------------------------------

  describe "renders dashboards index page with header and New Dashboard link" do
    test "renders dashboards index page with header and New Dashboard link", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, html} = live(conn, ~p"/dashboards")

        assert html =~ "Dashboards"
        assert has_element?(lv, "[data-role='new-dashboard-btn'][href='/dashboards/new']")
      end)
    end
  end

  describe "displays canned system dashboards with Built-in badge" do
    test "displays canned system dashboards with Built-in badge", %{conn: conn} do
      user = user_fixture()
      canned = canned_dashboard_fixture(user, %{name: "Traffic Overview"})
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, html} = live(conn, ~p"/dashboards")

        assert has_element?(lv, "[data-role='canned-dashboards']")
        assert html =~ "Traffic Overview"
        assert has_element?(
                 lv,
                 "[data-role='dashboard-card'][data-dashboard-id='#{canned.id}'][data-built-in='true']"
               )
        assert has_element?(lv, "[data-role='view-dashboard-#{canned.id}']")
        refute has_element?(lv, "[data-role='delete-dashboard-#{canned.id}']")
      end)
    end
  end

  describe "displays user-created dashboards with View, Edit, and Delete actions" do
    test "displays user-created dashboards with View, Edit, and Delete actions", %{conn: conn} do
      user = user_fixture()
      dashboard = dashboard_fixture(user, %{name: "Revenue Overview"})
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, html} = live(conn, ~p"/dashboards")

        assert html =~ "Revenue Overview"
        assert has_element?(
                 lv,
                 "[data-role='dashboard-card'][data-dashboard-id='#{dashboard.id}'][data-built-in='false']"
               )
        assert has_element?(lv, "[data-role='view-dashboard-#{dashboard.id}']")
        assert has_element?(lv, "[data-role='edit-dashboard-#{dashboard.id}']")
        assert has_element?(lv, "[data-role='delete-dashboard-#{dashboard.id}']")
      end)
    end
  end

  describe "shows empty state when user has no saved dashboards" do
    test "shows empty state when user has no saved dashboards", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboards")

        assert has_element?(lv, "[data-role='empty-user-dashboards']")
        assert has_element?(lv, "[data-role='empty-user-dashboards'] a[href='/dashboards/new']")
      end)
    end
  end

  describe "shows delete confirmation inline when Delete is clicked" do
    test "shows delete confirmation inline when Delete is clicked", %{conn: conn} do
      user = user_fixture()
      dashboard = dashboard_fixture(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboards")

        render_click(lv, "delete", %{"id" => to_string(dashboard.id)})

        assert has_element?(lv, "[data-role='delete-confirm-#{dashboard.id}']")
        assert has_element?(lv, "[data-role='confirm-delete-#{dashboard.id}']")
        assert has_element?(lv, "[data-role='cancel-delete']")
      end)
    end
  end

  describe "deletes dashboard and shows success flash on confirm" do
    test "deletes dashboard and shows success flash on confirm", %{conn: conn} do
      user = user_fixture()
      dashboard = dashboard_fixture(user, %{name: "To Be Deleted"})
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboards")

        render_click(lv, "delete", %{"id" => to_string(dashboard.id)})
        html = render_click(lv, "confirm_delete", %{"id" => to_string(dashboard.id)})

        assert html =~ "Dashboard deleted."
        refute has_element?(lv, "[data-role='dashboard-card'][data-dashboard-id='#{dashboard.id}']")
      end)
    end
  end

  describe "cancels delete confirmation without modifying data" do
    test "cancels delete confirmation without modifying data", %{conn: conn} do
      user = user_fixture()
      dashboard = dashboard_fixture(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboards")

        render_click(lv, "delete", %{"id" => to_string(dashboard.id)})
        assert has_element?(lv, "[data-role='delete-confirm-#{dashboard.id}']")

        render_click(lv, "cancel_delete", %{})
        refute has_element?(lv, "[data-role='delete-confirm-#{dashboard.id}']")
        assert has_element?(lv, "[data-role='dashboard-card'][data-dashboard-id='#{dashboard.id}']")
      end)
    end
  end

  describe "shows error when deleting a non-existent dashboard" do
    test "shows error when deleting a non-existent dashboard", %{conn: conn} do
      user = user_fixture()
      dashboard = dashboard_fixture(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboards")

        render_click(lv, "delete", %{"id" => to_string(dashboard.id)})
        Repo.delete!(dashboard)
        html = render_click(lv, "confirm_delete", %{"id" => to_string(dashboard.id)})

        assert html =~ "Dashboard not found."
      end)
    end
  end
end
