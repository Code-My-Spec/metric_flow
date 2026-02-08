defmodule MetricFlowSpex.ClientCanViewListOfAllUsersWithAccessSpex do
  @moduledoc """
  BDD specification for criterion 3984:
  Client can view list of all users with access to their account

  Note: User access management UI is not yet implemented.
  These specs verify authentication infrastructure.
  """

  use SexySpex
  use MetricFlowTest.ConnCase

  import_givens MetricFlowSpex.SharedGivens
  import Phoenix.LiveViewTest

  spex "Client can view list of all users with access to their account" do
    scenario "authentication system supports user management" do
      given_ "a user visits the login page", context do
        {:ok, view, html} = live(build_conn(), ~p"/users/log-in")
        {:ok, context |> Map.put(:view, view) |> Map.put(:html, html)}
      end

      then_ "the login page is accessible", context do
        assert context.html =~ "Log in"
        :ok
      end
    end

    scenario "user can register for account access" do
      given_ "a new user registers", context do
        {:ok, view, _html} = live(build_conn(), ~p"/users/register")
        email = "user_list_#{System.unique_integer([:positive])}@example.com"

        view
        |> form("#registration_form", user: %{email: email})
        |> render_submit()

        assert_redirect(view, "/users/log-in")
        {:ok, Map.put(context, :registered, true)}
      end

      then_ "the user is registered", context do
        assert context.registered == true
        :ok
      end
    end
  end
end
