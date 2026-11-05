defmodule MetricFlowWeb.VerifyControllerTest do
  use MetricFlowWeb.ConnCase, async: true

  test "the widget check refuses a request without the deploy key", %{conn: conn} do
    conn = post(conn, "/_cms/verify/widget", %{probe: "p"})
    assert json_response(conn, 401)["status"] == "unauthorized"
  end

  test "the always-failing route is down by construction", %{conn: conn} do
    assert json_response(get(conn, "/_cms/verify/always-failing"), 503)["status"] == "down"
  end
end
