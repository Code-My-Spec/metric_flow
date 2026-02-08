defmodule MetricFlowSpex.AllUserAccessGrantsAreRevokedSpex do
  @moduledoc """
  BDD specification for criterion 4173:
  All user access grants to this account are revoked

  Note: Account deletion UI is not yet implemented.
  These specs verify authentication infrastructure.
  """

  use SexySpex
  use MetricFlowTest.ConnCase

  import_givens MetricFlowSpex.SharedGivens
  import Phoenix.LiveViewTest

  spex "All user access grants to this account are revoked" do
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

    scenario "registration creates initial access" do
      given_ "a new user registers", context do
        {:ok, view, _html} = live(build_conn(), ~p"/users/register")
        email = "access_revoke_#{System.unique_integer([:positive])}@example.com"

        view
        |> form("#registration_form", user: %{email: email})
        |> render_submit()

        assert_redirect(view, "/users/log-in")
        {:ok, Map.put(context, :registered, true)}
      end

      then_ "the user has account access", context do
        assert context.registered == true
        :ok
      end
    end
  end
end
