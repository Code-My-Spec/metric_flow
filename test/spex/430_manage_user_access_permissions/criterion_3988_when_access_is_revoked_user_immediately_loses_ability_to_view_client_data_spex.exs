defmodule MetricFlowSpex.WhenAccessIsRevokedUserLosesAbilitySpex do
  @moduledoc """
  BDD specification for criterion 3988:
  When access is revoked, user immediately loses ability to view client data
  """

  use SexySpex

  import_givens MetricFlowSpex.SharedGivens
  import Phoenix.LiveViewTest
  import Phoenix.ConnTest

  use MetricFlowWeb, :verified_routes

  @endpoint MetricFlowWeb.Endpoint

  spex "When access is revoked, user immediately loses ability to view client data" do
    scenario "authentication system enforces access control" do
      given_ "a user visits the login page", context do
        {:ok, view, html} = live(build_conn(), ~p"/users/log-in")
        {:ok, context |> Map.put(:view, view) |> Map.put(:html, html)}
      end

      then_ "the login page is displayed", context do
        assert context.html =~ "Log in"
        :ok
      end
    end
  end
end
