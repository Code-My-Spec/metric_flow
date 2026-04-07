defmodule MetricFlowWeb.VisualizationLive.IndexTest do
  use MetricFlowTest.ConnCase, async: false

  import ExUnit.CaptureLog
  import Phoenix.LiveViewTest
  import MetricFlowTest.UsersFixtures

  alias MetricFlow.Dashboards.Visualization
  alias MetricFlow.Repo

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp visualization_fixture(user, attrs \\ %{}) do
    defaults = %{
      name: "Viz #{System.unique_integer([:positive])}",
      user_id: user.id,
      vega_spec: %{"$schema" => "https://vega.github.io/schema/vega-lite/v5.json"},
      shareable: false
    }

    %Visualization{}
    |> Visualization.changeset(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end

  # ---------------------------------------------------------------------------
  # mount/3
  # ---------------------------------------------------------------------------

  describe "mount/3" do
    test "renders visualization list for authenticated user", %{conn: conn} do
      user = user_fixture()
      visualization_fixture(user, %{name: "My Chart"})
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/app/visualizations")

        assert html =~ "My Chart"
        assert html =~ "Visualizations"
        send(self(), :done)
      end)

      assert_receive :done
    end

    test "shows empty state when user has no visualizations", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/app/visualizations")

        assert has_element?(lv, "[data-role='empty-visualizations']")
        send(self(), :done)
      end)

      assert_receive :done
    end

    test "redirects unauthenticated user to login", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} =
               live(conn, ~p"/app/visualizations")
    end
  end

  # ---------------------------------------------------------------------------
  # handle_event/3 ("delete")
  # ---------------------------------------------------------------------------

  describe ~s(handle_event/3 ("delete")) do
    test "shows delete confirmation for the targeted visualization", %{conn: conn} do
      user = user_fixture()
      viz = visualization_fixture(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/app/visualizations")

        lv |> element("[data-role='delete-visualization-#{viz.id}']") |> render_click()

        assert has_element?(lv, "[data-role='delete-confirm-#{viz.id}']")
        send(self(), :done)
      end)

      assert_receive :done
    end
  end

  # ---------------------------------------------------------------------------
  # handle_event/3 ("cancel_delete")
  # ---------------------------------------------------------------------------

  describe ~s(handle_event/3 ("cancel_delete")) do
    test "hides delete confirmation", %{conn: conn} do
      user = user_fixture()
      viz = visualization_fixture(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/app/visualizations")

        lv |> element("[data-role='delete-visualization-#{viz.id}']") |> render_click()
        assert has_element?(lv, "[data-role='delete-confirm-#{viz.id}']")

        lv |> element("[data-role='cancel-delete']") |> render_click()
        refute has_element?(lv, "[data-role='delete-confirm-#{viz.id}']")
        send(self(), :done)
      end)

      assert_receive :done
    end
  end

  # ---------------------------------------------------------------------------
  # handle_event/3 ("confirm_delete")
  # ---------------------------------------------------------------------------

  describe ~s(handle_event/3 ("confirm_delete")) do
    test "removes visualization from list and flashes success", %{conn: conn} do
      user = user_fixture()
      viz = visualization_fixture(user, %{name: "Doomed Viz"})
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/app/visualizations")

        lv |> element("[data-role='delete-visualization-#{viz.id}']") |> render_click()
        lv |> element("[data-role='confirm-delete-#{viz.id}']") |> render_click()

        html = render(lv)
        refute html =~ "Doomed Viz"
        assert html =~ "Visualization deleted."
        send(self(), :done)
      end)

      assert_receive :done
    end

    test "flashes error when visualization not found", %{conn: conn} do
      user = user_fixture()
      viz = visualization_fixture(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/app/visualizations")

        # Delete from DB directly, then try to confirm
        Repo.delete!(viz)

        lv |> element("[data-role='delete-visualization-#{viz.id}']") |> render_click()
        lv |> element("[data-role='confirm-delete-#{viz.id}']") |> render_click()

        html = render(lv)
        assert html =~ "not found"
        send(self(), :done)
      end)

      assert_receive :done
    end
  end

  # ---------------------------------------------------------------------------
  # render/1
  # ---------------------------------------------------------------------------

  describe "render/1" do
    test "renders visualization cards with data-role attributes", %{conn: conn} do
      user = user_fixture()
      viz = visualization_fixture(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/app/visualizations")

        assert has_element?(lv, "[data-role='visualization-card'][data-visualization-id='#{viz.id}']")
        send(self(), :done)
      end)

      assert_receive :done
    end

    test "renders new visualization button", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/app/visualizations")

        assert has_element?(lv, "[data-role='new-visualization-btn']")
        send(self(), :done)
      end)

      assert_receive :done
    end

    test "renders edit and delete buttons per card", %{conn: conn} do
      user = user_fixture()
      viz = visualization_fixture(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/app/visualizations")

        assert has_element?(lv, "[data-role='edit-visualization-#{viz.id}']")
        assert has_element?(lv, "[data-role='delete-visualization-#{viz.id}']")
        send(self(), :done)
      end)

      assert_receive :done
    end

    test "shows inline confirmation when confirming_delete is set", %{conn: conn} do
      user = user_fixture()
      viz = visualization_fixture(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/app/visualizations")

        refute has_element?(lv, "[data-role='delete-confirm-#{viz.id}']")

        lv |> element("[data-role='delete-visualization-#{viz.id}']") |> render_click()

        assert has_element?(lv, "[data-role='delete-confirm-#{viz.id}']")
        send(self(), :done)
      end)

      assert_receive :done
    end
  end
end
