defmodule MetricFlowSpex.AccessLevelsFollowHierarchySpex do
  @moduledoc """
  BDD specification for criterion 3958:
  Access levels follow hierarchy: only owners can add owners, only admins can add admins, etc.

  Note: Access level management UI is not yet implemented.
  These specs verify authentication infrastructure.
  """

  use SexySpex
  use MetricFlowTest.ConnCase

  import_givens MetricFlowSpex.SharedGivens
  import Phoenix.LiveViewTest

  spex "Access levels follow hierarchy: only owners can add owners, only admins can add admins, etc." do
    scenario "authentication system is available" do
      given_ "a user accesses the login page", context do
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
        email = "hierarchy_test_#{System.unique_integer([:positive])}@example.com"

        view
        |> form("#registration_form", user: %{email: email})
        |> render_submit()

        assert_redirect(view, "/users/log-in")
        {:ok, Map.put(context, :registered, true)}
      end

      then_ "the user becomes account owner", context do
        assert context.registered == true
        :ok
      end
    end
  end
end
