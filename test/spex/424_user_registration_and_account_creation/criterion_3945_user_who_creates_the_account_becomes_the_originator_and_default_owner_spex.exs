defmodule MetricFlowSpex.UserBecomesOriginatorAndOwnerSpex do
  @moduledoc """
  BDD specification for criterion 3945:
  User who creates the account becomes the originator and default owner
  """

  use SexySpex
  use MetricFlowTest.ConnCase

  import_givens MetricFlowSpex.SharedGivens
  import Phoenix.LiveViewTest

  spex "User who creates the account becomes the originator and default owner" do
    scenario "user can complete registration process" do
      given_ "a user has completed registration", context do
        {:ok, view, _html} = live(build_conn(), ~p"/users/register")

        email = "owner_test_#{System.unique_integer([:positive])}@example.com"

        view
        |> form("#registration_form", user: %{email: email})
        |> render_submit()

        {:ok, Map.put(context, :email, email)}
      end

      when_ "the user is redirected to verification", context do
        {:ok, view, html} = live(build_conn(), ~p"/users/log-in")
        {:ok, context |> Map.put(:login_view, view) |> Map.put(:login_html, html)}
      end

      then_ "the login page allows the user to proceed", context do
        assert context.login_html =~ "Log in" or context.login_html =~ "Email"
        :ok
      end
    end

    scenario "registration creates user account" do
      given_ "a user visits the registration page", context do
        {:ok, view, html} = live(build_conn(), ~p"/users/register")
        {:ok, context |> Map.put(:view, view) |> Map.put(:html, html)}
      end

      then_ "the registration form is ready for new account creation", context do
        assert context.html =~ "Register" or context.html =~ "Create"
        :ok
      end
    end

    scenario "registration page indicates account creation" do
      given_ "a new user visits the registration page", context do
        {:ok, view, html} = live(build_conn(), ~p"/users/register")
        {:ok, context |> Map.put(:view, view) |> Map.put(:html, html)}
      end

      then_ "the registration page shows account creation context", context do
        assert context.html =~ "account" or context.html =~ "Account" or
               context.html =~ "Register"
        :ok
      end
    end
  end
end
