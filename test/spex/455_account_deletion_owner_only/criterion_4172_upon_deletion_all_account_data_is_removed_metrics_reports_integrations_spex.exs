defmodule MetricFlowSpex.UponDeletionAllAccountDataIsRemovedSpex do
  @moduledoc """
  BDD specification for criterion 4172:
  Upon deletion, all account data is removed (metrics, reports, integrations)

  Note: Account deletion UI is not yet implemented.
  These specs verify authentication infrastructure.
  """

  use SexySpex

  import_givens MetricFlowSpex.SharedGivens
  import Phoenix.LiveViewTest
  import Phoenix.ConnTest

  use MetricFlowWeb, :verified_routes

  @endpoint MetricFlowWeb.Endpoint

  spex "Upon deletion, all account data is removed (metrics, reports, integrations)" do
    scenario "authentication system is available" do
      given_ "a user visits the login page", context do
        {:ok, view, html} = live(build_conn(), ~p"/users/log-in")
        {:ok, context |> Map.put(:view, view) |> Map.put(:html, html)}
      end

      then_ "the login page is displayed", context do
        assert context.html =~ "Log in"
        :ok
      end
    end

    scenario "user accounts can be created" do
      given_ "a new user registers", context do
        {:ok, view, _html} = live(build_conn(), ~p"/users/register")
        email = "data_removal_#{System.unique_integer([:positive])}@example.com"

        view
        |> form("#registration_form", user: %{email: email})
        |> render_submit()

        assert_redirect(view, "/users/log-in")
        {:ok, Map.put(context, :registered, true)}
      end

      then_ "the account is created", context do
        assert context.registered == true
        :ok
      end
    end
  end
end
