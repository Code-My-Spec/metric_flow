defmodule MetricFlowWeb.UserLive.AiHomeSubscriptionGateTest do
  use MetricFlowTest.ConnCase, async: false

  import Phoenix.LiveViewTest
  import MetricFlowTest.UsersFixtures
  import MetricFlowTest.AiFixtures

  @moduledoc """
  Regression for QA finding on issue b7b4f72d: a typical account holder
  (personal account, no subscription) logging in was redirected to
  /app/chat, the default home, but RequireSubscriptionHook gated that
  route and rendered the upgrade paywall instead of the AI greeting. The
  chat route no longer sits behind :require_subscription, so every
  authenticated user sees the greeting regardless of subscription status.
  """

  test "a user with a personal account but no subscription sees the AI greeting, not the paywall, after login",
       %{conn: conn} do
    {user, _scope} = user_with_scope()
    user = set_password(user)
    {:ok, view, _html} = live(conn, ~p"/users/log-in")

    conn =
      view
      |> form("#login_form_password",
        user: %{email: user.email, password: valid_user_password()}
      )
      |> submit_form(conn)

    assert redirected_to(conn) == ~p"/app/chat"

    {:ok, _home_view, home_html} = live(conn, redirected_to(conn))

    assert home_html =~ "What can I help you with today?"
    refute home_html =~ "Upgrade to access AI features"
  end
end
