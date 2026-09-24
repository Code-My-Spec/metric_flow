defmodule MetricFlowWeb.OnboardingLiveTest do
  use MetricFlowTest.ConnCase, async: true

  import Phoenix.LiveViewTest
  import MetricFlowTest.UsersFixtures

  # Logged in, because `/onboarding` sets up the signed-in user's own account and
  # the route requires a session. This mounted anonymously until 2026-09-23 and
  # only worked because the route sat in the `:current_user` live_session, which
  # mounts the scope without requiring one — `onboarding_live/index_test.exs`
  # asserts the redirect directly, and the two files disagreed.
  test "renders onboarding page", %{conn: conn} do
    conn = log_in_user(conn, user_fixture())

    {:ok, _lv, html} = live(conn, "/onboarding")
    assert html =~ "Welcome"
  end
end
