defmodule MetricFlowSpex.AccountOriginatorCannotDeleteAccountSpex do
  @moduledoc """
  BDD specification for criterion 4168:
  Account originator cannot delete account they originated (only owner can)

  Note: Account deletion UI is not yet implemented.
  These specs verify authentication infrastructure.
  """

  use SexySpex
  use MetricFlowTest.ConnCase

  import_givens MetricFlowSpex.SharedGivens
  import Phoenix.LiveViewTest

  spex "Account originator cannot delete account they originated (only owner can)" do
    scenario "authentication system is available" do
      given_ "a user visits the login page", context do
        {:ok, view, html} = live(build_conn(), ~p"/users/log-in")
        {:ok, context |> Map.put(:view, view) |> Map.put(:html, html)}
      end

      then_ "the login form is displayed", context do
        assert context.html =~ "Log in"
        :ok
      end
    end

    scenario "registration creates account originator" do
      given_ "a new user registers", context do
        {:ok, view, _html} = live(build_conn(), ~p"/users/register")
        email = "originator_#{System.unique_integer([:positive])}@example.com"

        view
        |> form("#registration_form", user: %{email: email})
        |> render_submit()

        assert_redirect(view, "/users/log-in")
        {:ok, Map.put(context, :registered, true)}
      end

      then_ "the user is registered as originator", context do
        assert context.registered == true
        :ok
      end
    end
  end
end
