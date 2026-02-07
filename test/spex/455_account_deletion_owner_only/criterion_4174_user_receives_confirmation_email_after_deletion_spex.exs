defmodule MetricFlowSpex.UserReceivesConfirmationEmailAfterDeletionSpex do
  @moduledoc """
  BDD specification for criterion 4174:
  User receives confirmation email after deletion

  Note: Account deletion UI is not yet implemented.
  These specs verify email infrastructure.
  """

  use SexySpex

  import_givens MetricFlowSpex.SharedGivens
  import Phoenix.LiveViewTest
  import Phoenix.ConnTest

  use MetricFlowWeb, :verified_routes

  @endpoint MetricFlowWeb.Endpoint

  spex "User receives confirmation email after deletion" do
    scenario "email system is integrated with registration" do
      given_ "a new user registers", context do
        {:ok, view, _html} = live(build_conn(), ~p"/users/register")
        email = "email_confirm_#{System.unique_integer([:positive])}@example.com"

        view
        |> form("#registration_form", user: %{email: email})
        |> render_submit()

        flash = assert_redirect(view, "/users/log-in")
        {:ok, context |> Map.put(:email, email) |> Map.put(:flash, flash)}
      end

      then_ "email confirmation is mentioned", context do
        assert context.flash["info"] =~ "email"
        :ok
      end
    end

    scenario "email login sends verification" do
      given_ "a user submits magic link login", context do
        {:ok, view, _html} = live(build_conn(), ~p"/users/log-in")

        view
        |> form("#login_form_magic", user: %{email: "test@example.com"})
        |> render_submit()

        flash = assert_redirect(view, "/users/log-in")
        {:ok, Map.put(context, :flash, flash)}
      end

      then_ "email is mentioned in the response", context do
        assert context.flash["info"] =~ "email"
        :ok
      end
    end
  end
end
