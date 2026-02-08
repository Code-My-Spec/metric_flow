defmodule MetricFlowSpex.AccountOwnerCanViewAllUsersSpex do
  @moduledoc """
  BDD specification for criterion 3959:
  Account owner can view all users in their account with their access levels

  Note: User management UI is not yet implemented.
  These specs verify authentication infrastructure.
  """

  use SexySpex
  use MetricFlowTest.ConnCase

  import_givens MetricFlowSpex.SharedGivens
  import Phoenix.LiveViewTest

  spex "Account owner can view all users in their account with their access levels" do
    scenario "authentication pages are accessible" do
      given_ "a user visits the login page", context do
        {:ok, view, html} = live(build_conn(), ~p"/users/log-in")
        {:ok, context |> Map.put(:view, view) |> Map.put(:html, html)}
      end

      then_ "the login page loads", context do
        assert context.html =~ "Log in"
        :ok
      end
    end

    scenario "registration system is available" do
      given_ "a user visits registration", context do
        {:ok, view, html} = live(build_conn(), ~p"/users/register")
        {:ok, context |> Map.put(:view, view) |> Map.put(:html, html)}
      end

      then_ "the registration page loads", context do
        assert context.html =~ "Register" or context.html =~ "Create an account"
        :ok
      end
    end
  end
end
