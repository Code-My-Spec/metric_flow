defmodule MetricFlowWeb.VisualizationLive.IndexTest do
  use MetricFlowTest.ConnCase, async: false

  import Phoenix.LiveViewTest
  import MetricFlowTest.UsersFixtures

  # Story 75: the saved-visualizations library page is retired in favor of
  # the one dashboards list at /app/dashboards. /visualizations/new and
  # /visualizations/:id/edit (VisualizationLive.Editor) are untouched --
  # see test/spex/29_llm-driven_visualization_authoring.
  test "redirects to the dashboards list", %{conn: conn} do
    user = user_fixture()
    conn = log_in_user(conn, user)

    assert {:error, {:redirect, %{to: "/app/dashboards"}}} = live(conn, ~p"/app/visualizations")
  end
end
