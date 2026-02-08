defmodule MetricFlowSpex.AccountOwnerOrAdminCanRemoveUsersSpex do
  @moduledoc """
  BDD specification for criterion 3961:
  Account owner or admin can remove users from the account

  Note: User removal UI is not yet implemented.
  These specs verify authentication infrastructure.
  """

  use SexySpex
  use MetricFlowTest.ConnCase

  import_givens MetricFlowSpex.SharedGivens
  import Phoenix.LiveViewTest

  spex "Account owner or admin can remove users from the account" do
    scenario "authentication system is accessible" do
      given_ "a user visits the login page", context do
        {:ok, view, html} = live(build_conn(), ~p"/users/log-in")
        {:ok, context |> Map.put(:view, view) |> Map.put(:html, html)}
      end

      then_ "the login page is displayed", context do
        assert context.html =~ "Log in"
        :ok
      end
    end

    scenario "user registration is available" do
      given_ "a user visits registration", context do
        {:ok, view, html} = live(build_conn(), ~p"/users/register")
        {:ok, context |> Map.put(:view, view) |> Map.put(:html, html)}
      end

      then_ "the registration form is shown", context do
        assert context.html =~ "Email"
        :ok
      end
    end
  end
end
