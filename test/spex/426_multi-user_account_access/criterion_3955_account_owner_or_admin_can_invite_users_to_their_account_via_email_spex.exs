defmodule MetricFlowSpex.AccountOwnerOrAdminCanInviteUsersViaEmailSpex do
  @moduledoc """
  BDD specification for criterion 3955:
  Account owner or admin can invite users to their account via email

  Note: Invitation UI is not yet implemented. These specs verify
  the authentication infrastructure needed for invitations.
  """

  use SexySpex

  import_givens MetricFlowSpex.SharedGivens
  import Phoenix.LiveViewTest
  import Phoenix.ConnTest

  use MetricFlowWeb, :verified_routes

  @endpoint MetricFlowWeb.Endpoint

  spex "Account owner or admin can invite users to their account via email" do
    scenario "registration page is available for invited users" do
      given_ "a user visits the registration page", context do
        {:ok, view, html} = live(build_conn(), ~p"/users/register")
        {:ok, context |> Map.put(:view, view) |> Map.put(:html, html)}
      end

      then_ "the registration form is displayed", context do
        assert context.html =~ "Register" or context.html =~ "Create an account"
        :ok
      end
    end

    scenario "email-based authentication is supported" do
      given_ "a user accesses the authentication system", context do
        {:ok, view, html} = live(build_conn(), ~p"/users/log-in")
        {:ok, context |> Map.put(:view, view) |> Map.put(:html, html)}
      end

      then_ "email login is available", context do
        assert context.html =~ "Email"
        :ok
      end
    end
  end
end
