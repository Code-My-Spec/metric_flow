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
  # describe "authentication"
  # ---------------------------------------------------------------------------

  describe "authentication" do
    test "redirects unauthenticated users to /users/log-in", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} =
               live(conn, ~p"/dashboards")
    end
  end

  # ---------------------------------------------------------------------------
  # describe "mount/3"
  # ---------------------------------------------------------------------------

  describe "mount/3" do
    test "renders the dashboards index page for an authenticated user", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/dashboards")

        assert is_binary(html)
      end)
    end

    test "shows the 'Dashboards' page heading", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/dashboards")

        assert html =~ "Dashboards"
      end)
    end

    test "shows the 'New Dashboard' button linking to /dashboards/new", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboards")

        assert has_element?(lv, "[data-role='new-dashboard-btn'][href='/dashboards/new']")
      end)
    end

    test "shows the user dashboards section", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboards")

        assert has_element?(lv, "[data-role='user-dashboards']")
      end)
    end

    test "shows the empty state when the user has no dashboards", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboards")

        assert has_element?(lv, "[data-role='empty-user-dashboards']")
      end)
    end

    test "shows the 'Create your first dashboard' link in the empty state", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboards")

        assert has_element?(lv, "[data-role='empty-user-dashboards'] a[href='/dashboards/new']")
      end)
    end

    test "does not show the empty state when the user has at least one dashboard", %{conn: conn} do
      user = user_fixture()
      dashboard_fixture(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboards")

        refute has_element?(lv, "[data-role='empty-user-dashboards']")
      end)
    end

    test "shows the user's dashboard card when they have a dashboard", %{conn: conn} do
      user = user_fixture()
      dashboard = dashboard_fixture(user, %{name: "Revenue Overview"})
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboards")

        assert has_element?(
                 lv,
                 "[data-role='dashboard-card'][data-dashboard-id='#{dashboard.id}'][data-built-in='false']"
               )
      end)
    end

    test "shows the dashboard name in the user dashboard card", %{conn: conn} do
      user = user_fixture()
      dashboard_fixture(user, %{name: "Revenue Overview"})
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/dashboards")

        assert html =~ "Revenue Overview"
      end)
    end

    test "shows the 'View' link for the user's dashboard", %{conn: conn} do
      user = user_fixture()
      dashboard = dashboard_fixture(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboards")

        assert has_element?(lv, "[data-role='view-dashboard-#{dashboard.id}']")
      end)
    end

    test "shows the 'Edit' link for the user's dashboard", %{conn: conn} do
      user = user_fixture()
      dashboard = dashboard_fixture(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboards")

        assert has_element?(lv, "[data-role='edit-dashboard-#{dashboard.id}']")
      end)
    end

    test "shows the 'Delete' button for the user's dashboard", %{conn: conn} do
      user = user_fixture()
      dashboard = dashboard_fixture(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboards")

        assert has_element?(lv, "[data-role='delete-dashboard-#{dashboard.id}']")
      end)
    end

    test "does not show the canned dashboards section when no built-in dashboards exist", %{
      conn: conn
    } do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboards")

        refute has_element?(lv, "[data-role='canned-dashboards']")
      end)
    end

    test "shows the canned dashboards section when at least one built-in dashboard exists", %{
      conn: conn
    } do
      user = user_fixture()
      canned_dashboard_fixture(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboards")

        assert has_element?(lv, "[data-role='canned-dashboards']")
      end)
    end

    test "shows the built-in dashboard card with data-built-in='true'", %{conn: conn} do
      user = user_fixture()
      canned = canned_dashboard_fixture(user, %{name: "Traffic Overview"})
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboards")

        assert has_element?(
                 lv,
                 "[data-role='dashboard-card'][data-dashboard-id='#{canned.id}'][data-built-in='true']"
               )
      end)
    end

    test "shows the built-in dashboard name in the canned dashboard card", %{conn: conn} do
      user = user_fixture()
      canned_dashboard_fixture(user, %{name: "Traffic Overview"})
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/dashboards")

        assert html =~ "Traffic Overview"
      end)
    end

    test "shows the 'View' link for the built-in dashboard", %{conn: conn} do
      user = user_fixture()
      canned = canned_dashboard_fixture(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboards")

        assert has_element?(lv, "[data-role='view-dashboard-#{canned.id}']")
      end)
    end

    test "does not show the 'Delete' button for the built-in dashboard", %{conn: conn} do
      user = user_fixture()
      canned = canned_dashboard_fixture(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboards")

        refute has_element?(lv, "[data-role='delete-dashboard-#{canned.id}']")
      end)
    end

    test "does not show the description when the dashboard has no description", %{conn: conn} do
      user = user_fixture()
      dashboard_fixture(user, %{name: "No Description Dashboard", description: nil})
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/dashboards")

        assert html =~ "No Description Dashboard"
      end)
    end

    test "shows the dashboard description when one is set", %{conn: conn} do
      user = user_fixture()
      dashboard_fixture(user, %{name: "My Dashboard", description: "Tracks key metrics"})
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/dashboards")

        assert html =~ "Tracks key metrics"
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_event \"delete\""
  # ---------------------------------------------------------------------------

  describe "handle_event \"delete\"" do
    test "shows the inline delete confirmation when delete is clicked", %{conn: conn} do
      user = user_fixture()
      dashboard = dashboard_fixture(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboards")

        render_click(lv, "delete", %{"id" => to_string(dashboard.id)})

        assert has_element?(lv, "[data-role='delete-confirm-#{dashboard.id}']")
      end)
    end

    test "shows the confirm-delete button after clicking delete", %{conn: conn} do
      user = user_fixture()
      dashboard = dashboard_fixture(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboards")

        render_click(lv, "delete", %{"id" => to_string(dashboard.id)})

        assert has_element?(lv, "[data-role='confirm-delete-#{dashboard.id}']")
      end)
    end

    test "shows the cancel-delete button after clicking delete", %{conn: conn} do
      user = user_fixture()
      dashboard = dashboard_fixture(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboards")

        render_click(lv, "delete", %{"id" => to_string(dashboard.id)})

        assert has_element?(lv, "[data-role='cancel-delete']")
      end)
    end

    test "does not show delete confirmation for other dashboards when one is selected", %{
      conn: conn
    } do
      user = user_fixture()
      dashboard_a = dashboard_fixture(user, %{name: "Dashboard A"})
      dashboard_b = dashboard_fixture(user, %{name: "Dashboard B"})
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboards")

        render_click(lv, "delete", %{"id" => to_string(dashboard_a.id)})

        assert has_element?(lv, "[data-role='delete-confirm-#{dashboard_a.id}']")
        refute has_element?(lv, "[data-role='delete-confirm-#{dashboard_b.id}']")
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_event \"confirm_delete\""
  # ---------------------------------------------------------------------------

  describe "handle_event \"confirm_delete\"" do
    test "removes the dashboard from the list after confirming delete", %{conn: conn} do
      user = user_fixture()
      dashboard = dashboard_fixture(user, %{name: "To Be Deleted"})
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboards")

        render_click(lv, "delete", %{"id" => to_string(dashboard.id)})
        render_click(lv, "confirm_delete", %{"id" => to_string(dashboard.id)})

        refute has_element?(
                 lv,
                 "[data-role='dashboard-card'][data-dashboard-id='#{dashboard.id}']"
               )
      end)
    end

    test "flashes 'Dashboard deleted.' after confirming delete", %{conn: conn} do
      user = user_fixture()
      dashboard = dashboard_fixture(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboards")

        render_click(lv, "delete", %{"id" => to_string(dashboard.id)})
        html = render_click(lv, "confirm_delete", %{"id" => to_string(dashboard.id)})

        assert html =~ "Dashboard deleted."
      end)
    end

    test "clears the confirming_delete state after confirming delete", %{conn: conn} do
      user = user_fixture()
      dashboard = dashboard_fixture(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboards")

        render_click(lv, "delete", %{"id" => to_string(dashboard.id)})
        render_click(lv, "confirm_delete", %{"id" => to_string(dashboard.id)})

        refute has_element?(lv, "[data-role='delete-confirm-#{dashboard.id}']")
      end)
    end

    test "flashes an error when the dashboard is not found", %{conn: conn} do
      user = user_fixture()
      dashboard = dashboard_fixture(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboards")

        render_click(lv, "delete", %{"id" => to_string(dashboard.id)})

        # Delete the record from the DB to simulate not found
        Repo.delete!(dashboard)

        html = render_click(lv, "confirm_delete", %{"id" => to_string(dashboard.id)})

        assert html =~ "Dashboard not found."
      end)
    end

    test "flashes an error when attempting to delete a built-in dashboard", %{conn: conn} do
      user = user_fixture()
      canned = canned_dashboard_fixture(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboards")

        render_click(lv, "confirm_delete", %{"id" => to_string(canned.id)})

        assert has_element?(lv, "[role='alert']", "You can")
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_event \"cancel_delete\""
  # ---------------------------------------------------------------------------

  describe "handle_event \"cancel_delete\"" do
    test "hides the inline delete confirmation after clicking cancel", %{conn: conn} do
      user = user_fixture()
      dashboard = dashboard_fixture(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboards")

        render_click(lv, "delete", %{"id" => to_string(dashboard.id)})

        assert has_element?(lv, "[data-role='delete-confirm-#{dashboard.id}']")

        render_click(lv, "cancel_delete", %{})

        refute has_element?(lv, "[data-role='delete-confirm-#{dashboard.id}']")
      end)
    end

    test "keeps the dashboard card visible after cancelling delete", %{conn: conn} do
      user = user_fixture()
      dashboard = dashboard_fixture(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/dashboards")

        render_click(lv, "delete", %{"id" => to_string(dashboard.id)})
        render_click(lv, "cancel_delete", %{})

        assert has_element?(
                 lv,
                 "[data-role='dashboard-card'][data-dashboard-id='#{dashboard.id}']"
               )
      end)
    end
  end
end
