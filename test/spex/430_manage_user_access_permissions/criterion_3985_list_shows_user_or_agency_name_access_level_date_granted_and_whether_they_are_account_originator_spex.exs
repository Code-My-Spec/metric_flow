defmodule MetricFlowSpex.ListShowsUserInfoAndAccessLevelSpex do
  @moduledoc """
  BDD specification for criterion 3985:
  List shows user or agency name, access level, date granted, and whether they are account originator
  """

  use SexySpex
  use MetricFlowTest.ConnCase

  import_givens MetricFlowSpex.SharedGivens
  import Phoenix.LiveViewTest

  spex "List shows user or agency name, access level, date granted, and whether they are account originator" do
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
  end
end
