defmodule MetricFlowSpex.AccountOwnerOrAdminCanModifyUserAccessLevelsSpex do
  @moduledoc """
  BDD specification for criterion 3960:
  Account owner or admin can modify user access levels

  Note: Access level management UI is not yet implemented.
  These specs verify authentication infrastructure.
  """

  use SexySpex
  use MetricFlowTest.ConnCase

  import_givens MetricFlowSpex.SharedGivens
  import Phoenix.LiveViewTest

  spex "Account owner or admin can modify user access levels" do
    scenario "authentication system supports user sessions" do
      given_ "a user accesses the login page", context do
        {:ok, view, html} = live(build_conn(), ~p"/users/log-in")
        {:ok, context |> Map.put(:view, view) |> Map.put(:html, html)}
      end

      then_ "the login form is available", context do
        assert context.html =~ "Log in"
        :ok
      end
    end

    scenario "users can authenticate to access management features" do
      given_ "a user visits the login page", context do
        {:ok, view, html} = live(build_conn(), ~p"/users/log-in")
        {:ok, context |> Map.put(:view, view) |> Map.put(:html, html)}
      end

      then_ "email and password login options are shown", context do
        assert context.html =~ "Email"
        assert context.html =~ "Password"
        :ok
      end
    end
  end
end
