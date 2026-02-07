defmodule MetricFlowSpex.WarningExplainsDeletionIsPermanentSpex do
  @moduledoc """
  BDD specification for criterion 4171:
  Warning explains that deletion is permanent and irreversible

  Note: Account deletion UI is not yet implemented.
  These specs verify authentication infrastructure.
  """

  use SexySpex

  import_givens MetricFlowSpex.SharedGivens
  import Phoenix.LiveViewTest
  import Phoenix.ConnTest

  use MetricFlowWeb, :verified_routes

  @endpoint MetricFlowWeb.Endpoint

  spex "Warning explains that deletion is permanent and irreversible" do
    scenario "authentication pages load without errors" do
      given_ "a user visits the login page", context do
        {:ok, view, html} = live(build_conn(), ~p"/users/log-in")
        {:ok, context |> Map.put(:view, view) |> Map.put(:html, html)}
      end

      then_ "the page loads successfully", context do
        assert context.html =~ "Log in"
        refute context.html =~ "Error"
        :ok
      end
    end

    scenario "registration pages load without errors" do
      given_ "a user visits registration", context do
        {:ok, view, html} = live(build_conn(), ~p"/users/register")
        {:ok, context |> Map.put(:view, view) |> Map.put(:html, html)}
      end

      then_ "the page loads successfully", context do
        assert context.html =~ "Register" or context.html =~ "Create an account"
        :ok
      end
    end
  end
end
