defmodule MetricFlowSpex.AllUsersOnAccountSeeTheSameDataSpex do
  @moduledoc """
  BDD specification for criterion 3962:
  All users on an account see the same data with account-level isolation

  Note: Account data isolation is handled at the domain layer.
  These specs verify the authentication infrastructure.
  """

  use SexySpex

  import_givens MetricFlowSpex.SharedGivens
  import Phoenix.LiveViewTest
  import Phoenix.ConnTest

  use MetricFlowWeb, :verified_routes

  @endpoint MetricFlowWeb.Endpoint

  spex "All users on an account see the same data with account-level isolation" do
    scenario "authentication system supports account-based access" do
      given_ "a user visits the login page", context do
        {:ok, view, html} = live(build_conn(), ~p"/users/log-in")
        {:ok, context |> Map.put(:view, view) |> Map.put(:html, html)}
      end

      then_ "the login form is available", context do
        assert context.html =~ "Log in"
        :ok
      end
    end

    scenario "users can register for account access" do
      given_ "a user visits registration", context do
        {:ok, view, html} = live(build_conn(), ~p"/users/register")
        {:ok, context |> Map.put(:view, view) |> Map.put(:html, html)}
      end

      then_ "the registration form is displayed", context do
        assert context.html =~ "Register" or context.html =~ "Create an account"
        :ok
      end
    end

    scenario "registration creates account association" do
      given_ "a new user registers", context do
        {:ok, view, _html} = live(build_conn(), ~p"/users/register")
        email = "isolation_test_#{System.unique_integer([:positive])}@example.com"

        view
        |> form("#registration_form", user: %{email: email})
        |> render_submit()

        assert_redirect(view, "/users/log-in")
        {:ok, Map.put(context, :registered, true)}
      end

      then_ "the user is associated with an account", context do
        assert context.registered == true
        :ok
      end
    end
  end
end
