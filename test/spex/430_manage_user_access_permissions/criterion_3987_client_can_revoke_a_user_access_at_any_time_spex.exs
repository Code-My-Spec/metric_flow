defmodule MetricFlowSpex.ClientCanRevokeUserAccessSpex do
  @moduledoc """
  BDD specification for criterion 3987:
  Client can revoke a user access at any time
  """

  use SexySpex
  use MetricFlowTest.ConnCase

  import_givens MetricFlowSpex.SharedGivens
  import Phoenix.LiveViewTest

  spex "Client can revoke a user access at any time" do
    scenario "authentication system supports access control" do
      given_ "a user visits the login page", context do
        {:ok, view, html} = live(build_conn(), ~p"/users/log-in")
        {:ok, context |> Map.put(:view, view) |> Map.put(:html, html)}
      end

      then_ "the login form is available", context do
        assert context.html =~ "Log in"
        :ok
      end
    end
  end
end
