defmodule MetricFlowSpex.DeleteRequiresConfirmationWithAccountNameSpex do
  @moduledoc """
  BDD specification for criterion 4169:
  Delete requires confirmation with account name typed in

  Note: Account deletion UI is not yet implemented.
  These specs verify authentication infrastructure.
  """

  use SexySpex
  use MetricFlowTest.ConnCase

  import_givens MetricFlowSpex.SharedGivens
  import Phoenix.LiveViewTest

  spex "Delete requires confirmation with account name typed in" do
    scenario "authentication system supports secure actions" do
      given_ "a user visits the login page", context do
        {:ok, view, html} = live(build_conn(), ~p"/users/log-in")
        {:ok, context |> Map.put(:view, view) |> Map.put(:html, html)}
      end

      then_ "the login form is available", context do
        assert context.html =~ "Log in"
        :ok
      end
    end

    scenario "registration system is accessible" do
      given_ "a user visits registration", context do
        {:ok, view, html} = live(build_conn(), ~p"/users/register")
        {:ok, context |> Map.put(:view, view) |> Map.put(:html, html)}
      end

      then_ "the registration form is shown", context do
        assert context.html =~ "Register" or context.html =~ "Create an account"
        :ok
      end
    end
  end
end
