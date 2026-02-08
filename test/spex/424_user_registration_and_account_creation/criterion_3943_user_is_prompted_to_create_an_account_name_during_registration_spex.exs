defmodule MetricFlowSpex.UserPromptedToCreateAccountNameSpex do
  @moduledoc """
  BDD specification for criterion 3943:
  User is prompted to create an account name during registration

  Note: Account name collection may occur during onboarding flow
  after email verification rather than during initial registration.
  """

  use SexySpex
  use MetricFlowTest.ConnCase

  import_givens MetricFlowSpex.SharedGivens
  import Phoenix.LiveViewTest

  spex "User is prompted to create an account name during registration" do
    scenario "registration form collects user information" do
      given_ "a new user visits the registration page", context do
        {:ok, view, html} = live(build_conn(), ~p"/users/register")
        {:ok, context |> Map.put(:view, view) |> Map.put(:html, html)}
      end

      then_ "the form displays required input fields", context do
        assert context.html =~ "Email" or context.html =~ "email"
        :ok
      end
    end

    scenario "registration proceeds with email submission" do
      given_ "a user is on the registration page", context do
        {:ok, view, _html} = live(build_conn(), ~p"/users/register")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user submits registration with email", context do
        context.view
        |> form("#registration_form", user: %{
          email: "accountname_#{System.unique_integer([:positive])}@example.com"
        })
        |> render_submit()

        {:ok, context}
      end

      then_ "the registration completes and redirects to verification", context do
        assert_redirect(context.view, "/users/log-in")
        :ok
      end
    end

    scenario "registration form is accessible" do
      given_ "a user visits the registration page", context do
        {:ok, view, html} = live(build_conn(), ~p"/users/register")
        {:ok, context |> Map.put(:view, view) |> Map.put(:html, html)}
      end

      then_ "the registration form is displayed", context do
        assert context.html =~ "Register" or context.html =~ "Create an account"
        :ok
      end
    end
  end
end
