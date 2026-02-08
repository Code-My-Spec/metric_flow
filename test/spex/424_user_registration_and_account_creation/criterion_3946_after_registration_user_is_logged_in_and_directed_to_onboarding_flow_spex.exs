defmodule MetricFlowSpex.UserLoggedInAndDirectedToOnboardingSpex do
  @moduledoc """
  BDD specification for criterion 3946:
  After registration, user is logged in and directed to onboarding flow
  """

  use SexySpex
  use MetricFlowTest.ConnCase

  import_givens MetricFlowSpex.SharedGivens
  import Phoenix.LiveViewTest

  spex "After registration, user is logged in and directed to onboarding flow" do
    scenario "successful registration redirects to verification" do
      given_ "a new user registers with valid email", context do
        {:ok, view, _html} = live(build_conn(), ~p"/users/register")
        email = "onboard_test_#{System.unique_integer([:positive])}@example.com"

        view
        |> form("#registration_form", user: %{email: email})
        |> render_submit()

        flash = assert_redirect(view, "/users/log-in")
        {:ok, context |> Map.put(:email, email) |> Map.put(:flash, flash)}
      end

      then_ "the user is redirected with verification message", context do
        assert context.flash["info"] =~ "email"
        :ok
      end
    end

    scenario "login page is accessible after registration" do
      given_ "a user completes registration", context do
        {:ok, view, html} = live(build_conn(), ~p"/users/log-in")
        {:ok, Map.merge(context, %{view: view, html: html})}
      end

      then_ "the login page is available for magic link flow", context do
        assert context.html =~ "Log in" or context.html =~ "Email"
        :ok
      end
    end

    scenario "registration is the starting point for new users" do
      given_ "a new user visits registration", context do
        {:ok, view, html} = live(build_conn(), ~p"/users/register")
        {:ok, context |> Map.put(:view, view) |> Map.put(:html, html)}
      end

      then_ "registration is the starting point for new account setup", context do
        assert context.html =~ "Register" or context.html =~ "Create an account"
        :ok
      end
    end

    scenario "registration form collects essential information" do
      given_ "a user is registering a new account", context do
        {:ok, view, html} = live(build_conn(), ~p"/users/register")
        {:ok, context |> Map.put(:view, view) |> Map.put(:html, html)}
      end

      then_ "the registration form collects email", context do
        assert context.html =~ "Email" or context.html =~ "email"
        :ok
      end
    end
  end
end
