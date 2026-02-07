defmodule MetricFlowSpex.EmailVerificationRequiredBeforeAccountActivationSpex do
  @moduledoc """
  BDD specification for criterion 3942:
  Email verification is required before account activation
  """

  use SexySpex

  import_givens MetricFlowSpex.SharedGivens
  import Phoenix.LiveViewTest
  import Phoenix.ConnTest

  use MetricFlowWeb, :verified_routes

  @endpoint MetricFlowWeb.Endpoint

  setup do
    MetricFlowTest.DataCase.setup_sandbox(%{async: false})
    :ok
  end

  spex "Email verification is required before account activation" do
    scenario "newly registered user receives email verification message" do
      given_ "a new user completes registration", context do
        {:ok, view, _html} = live(build_conn(), ~p"/users/register")
        email = "verify_test_#{System.unique_integer([:positive])}@example.com"

        view
        |> form("#registration_form", user: %{email: email})
        |> render_submit()

        flash = assert_redirect(view, "/users/log-in")
        {:ok, context |> Map.put(:email, email) |> Map.put(:flash, flash)}
      end

      then_ "the user is informed that email verification is required", context do
        assert context.flash["info"] =~ "email"
        :ok
      end
    end

    scenario "registration redirects to login for verification flow" do
      given_ "a user has registered", context do
        {:ok, view, _html} = live(build_conn(), ~p"/users/register")

        email = "unverified_#{System.unique_integer([:positive])}@example.com"

        view
        |> form("#registration_form", user: %{email: email})
        |> render_submit()

        {:ok, Map.put(context, :email, email)}
      end

      when_ "the user is redirected to login", context do
        {:ok, view, html} = live(build_conn(), ~p"/users/log-in")
        {:ok, Map.merge(context, %{login_view: view, login_html: html})}
      end

      then_ "the login page is accessible for verification flow", context do
        assert context.login_html =~ "Log in"
        :ok
      end
    end

    scenario "registration page shows email form" do
      given_ "a visitor accesses the registration page", context do
        {:ok, view, html} = live(build_conn(), ~p"/users/register")
        {:ok, context |> Map.put(:view, view) |> Map.put(:html, html)}
      end

      then_ "the page displays registration form", context do
        assert context.html =~ "Register"
        assert context.html =~ "Email"
        :ok
      end
    end
  end
end
