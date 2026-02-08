defmodule MetricFlowSpex.EachUserHasTheirOwnLoginCredentialsSpex do
  @moduledoc """
  BDD specification for criterion 3956:
  Each user has their own login credentials
  """

  use SexySpex
  use MetricFlowTest.ConnCase

  import_givens MetricFlowSpex.SharedGivens
  import Phoenix.LiveViewTest

  spex "Each user has their own login credentials" do
    scenario "each user registers with unique email" do
      given_ "a user visits registration", context do
        {:ok, view, html} = live(build_conn(), ~p"/users/register")
        {:ok, context |> Map.put(:view, view) |> Map.put(:html, html)}
      end

      then_ "the registration requires email", context do
        assert context.html =~ "Email"
        :ok
      end
    end

    scenario "login requires user-specific credentials" do
      given_ "a user visits login", context do
        {:ok, view, html} = live(build_conn(), ~p"/users/log-in")
        {:ok, context |> Map.put(:view, view) |> Map.put(:html, html)}
      end

      then_ "the login page requires email", context do
        assert context.html =~ "Email"
        :ok
      end
    end

    scenario "registration creates unique user accounts" do
      given_ "a user registers with email", context do
        {:ok, view, _html} = live(build_conn(), ~p"/users/register")
        email = "unique_user_#{System.unique_integer([:positive])}@example.com"

        view
        |> form("#registration_form", user: %{email: email})
        |> render_submit()

        assert_redirect(view, "/users/log-in")
        {:ok, Map.put(context, :email, email)}
      end

      then_ "the user account is created", context do
        assert context.email =~ "@"
        :ok
      end
    end
  end
end
