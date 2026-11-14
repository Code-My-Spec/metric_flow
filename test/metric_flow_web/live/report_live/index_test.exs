defmodule MetricFlowWeb.ReportLive.IndexTest do
  use MetricFlowTest.ConnCase, async: false

  import Phoenix.LiveViewTest
  import MetricFlowTest.UsersFixtures

  # Story 75: the reports list is retired in favor of the one dashboards
  # list at /app/dashboards. /reports/new, /reports/:id (ReportLive.Show)
  # and /reports/generate (AiLive.ReportGenerator) are untouched.
  test "redirects to the dashboards list", %{conn: conn} do
    user = user_fixture()
    conn = log_in_user(conn, user)

    assert {:error, {:redirect, %{to: "/app/dashboards"}}} = live(conn, ~p"/app/reports")
  end
end
