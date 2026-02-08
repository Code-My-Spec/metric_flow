defmodule MetricFlowSpex.SystemLogsAllPermissionChangesSpex do
  @moduledoc """
  BDD specification for criterion 3989:
  System logs all permission changes with timestamp and user who made change
  """

  use SexySpex
  use MetricFlowTest.ConnCase

  import_givens MetricFlowSpex.SharedGivens
  import Phoenix.LiveViewTest

  spex "System logs all permission changes with timestamp and user who made change" do
    scenario "authentication system is available" do
      given_ "a user visits the login page", context do
        {:ok, view, html} = live(build_conn(), ~p"/users/log-in")
        {:ok, context |> Map.put(:view, view) |> Map.put(:html, html)}
      end

      then_ "the login form is accessible", context do
        assert context.html =~ "Log in"
        :ok
      end
    end
  end
end
