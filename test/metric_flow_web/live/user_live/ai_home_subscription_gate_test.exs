defmodule MetricFlowWeb.UserLive.AiHomeSubscriptionGateTest do
  use MetricFlowTest.ConnCase, async: false

  import Phoenix.LiveViewTest
  import MetricFlowTest.UsersFixtures
  import MetricFlowTest.AiFixtures

  @moduledoc """
  QA finding on issue b7b4f72d: a typical account holder (personal account,
  no subscription) logging in is redirected to /app/chat, the new default
  home, but RequireSubscriptionHook gates that route and renders the
  upgrade paywall instead of the AI greeting. Only an account-less user
  (as in the issue's own reproduction fixture) sees the greeting today.
  """

  test "a user with a personal account but no subscription sees the paywall, not the AI greeting, after login",
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

    refute home_html =~ "What can I help you with today?"
    assert home_html =~ "Upgrade to access AI features"
  end
end
