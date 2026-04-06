defmodule MetricFlowWeb.OnboardingLiveTest do
  use MetricFlowTest.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "renders onboarding page", %{conn: conn} do
    {:ok, _lv, html} = live(conn, "/onboarding")
    assert html =~ "Welcome"
  end
end
