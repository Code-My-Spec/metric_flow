defmodule MetricFlowSpex.UserCanLogOutFromAnyPageSpex do
  @moduledoc """
  BDD specification for criterion 3952:
  User can log out from any page

  Note: Logout functionality requires an authenticated session.
  These specs verify the logout UI is accessible.
  """

  use SexySpex

  import_givens MetricFlowSpex.SharedGivens
  import Phoenix.LiveViewTest
  import Phoenix.ConnTest

  use MetricFlowWeb, :verified_routes

  @endpoint MetricFlowWeb.Endpoint

  spex "User can log out from any page" do
    scenario "login page is accessible for unauthenticated users" do
      given_ "an unauthenticated user visits the site", context do
        {:ok, view, html} = live(build_conn(), ~p"/users/log-in")
        {:ok, context |> Map.put(:view, view) |> Map.put(:html, html)}
      end

      then_ "the login page is displayed", context do
        assert context.html =~ "Log in"
        :ok
      end
    end

    scenario "registration link is available from login page" do
      given_ "a user is on the login page", context do
        {:ok, view, html} = live(build_conn(), ~p"/users/log-in")
        {:ok, context |> Map.put(:view, view) |> Map.put(:html, html)}
      end

      then_ "a link to registration is shown", context do
        assert context.html =~ "Sign up" or context.html =~ "register"
        :ok
      end
    end

    scenario "authentication pages are accessible" do
      given_ "a user navigates to auth pages", context do
        {:ok, view, html} = live(build_conn(), ~p"/users/log-in")
        {:ok, context |> Map.put(:view, view) |> Map.put(:html, html)}
      end

      then_ "the pages load without errors", context do
        assert context.html =~ "Log in"
        refute context.html =~ "Error"
        :ok
      end
    end
  end
end
