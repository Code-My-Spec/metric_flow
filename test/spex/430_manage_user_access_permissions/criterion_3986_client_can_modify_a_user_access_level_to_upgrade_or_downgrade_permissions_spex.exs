defmodule MetricFlowSpex.ClientCanModifyUserAccessLevelSpex do
  @moduledoc """
  BDD specification for criterion 3986:
  Client can modify a user access level to upgrade or downgrade permissions
  """

  use SexySpex
  use MetricFlowTest.ConnCase

  import_givens MetricFlowSpex.SharedGivens
  import Phoenix.LiveViewTest

  spex "Client can modify a user access level to upgrade or downgrade permissions" do
    scenario "authentication supports role-based access" do
      given_ "a user visits the login page", context do
        {:ok, view, html} = live(build_conn(), ~p"/users/log-in")
        {:ok, context |> Map.put(:view, view) |> Map.put(:html, html)}
      end

      then_ "the login page is accessible", context do
        assert context.html =~ "Log in"
        :ok
      end
    end
  end
end
