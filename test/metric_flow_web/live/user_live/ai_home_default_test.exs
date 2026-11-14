defmodule MetricFlowWeb.UserLive.AiHomeDefaultTest do
  use MetricFlowTest.ConnCase, async: false

  import Phoenix.LiveViewTest
  import MetricFlowTest.UsersFixtures

  @moduledoc """
  Reproduces issue b7b4f72d: AI chat should be the default authenticated
  home screen after login, greeting the user with "What can I help you
  with today?". Today login redirects to /app/integrations instead.
  """

  test "after login, the default authenticated home greets with the AI chat headline", %{
    conn: conn
  } do
    user = user_fixture() |> set_password()
    {:ok, view, _html} = live(conn, ~p"/users/log-in")

    conn =
      view
      |> form("#login_form_password",
        user: %{email: user.email, password: valid_user_password()}
      )
      |> submit_form(conn)

    {:ok, _home_view, home_html} = live(conn, redirected_to(conn))

    assert home_html =~ "What can I help you with today?"
  end
end
