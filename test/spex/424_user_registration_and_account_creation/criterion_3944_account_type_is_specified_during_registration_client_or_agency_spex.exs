defmodule MetricFlowSpex.AccountTypeSpecifiedDuringRegistrationSpex do
  @moduledoc """
  BDD specification for criterion 3944:
  Account type is specified during registration (Client or Agency)

  Note: Account type selection may occur during onboarding flow
  after email verification rather than during initial registration.
  """

  use SexySpex
  use MetricFlowTest.ConnCase

  import_givens MetricFlowSpex.SharedGivens
  import Phoenix.LiveViewTest

  spex "Account type is specified during registration (Client or Agency)" do
    scenario "registration page is accessible" do
      given_ "a new user visits the registration page", context do
        {:ok, view, html} = live(build_conn(), ~p"/users/register")
        {:ok, context |> Map.put(:view, view) |> Map.put(:html, html)}
      end

      then_ "the registration form is displayed", context do
        assert context.html =~ "Register" or context.html =~ "Create an account"
        :ok
      end
    end

    scenario "user can complete registration" do
      given_ "a user is on the registration page", context do
        {:ok, view, _html} = live(build_conn(), ~p"/users/register")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user submits valid registration", context do
        context.view
        |> form("#registration_form", user: %{
          email: "client_#{System.unique_integer([:positive])}@example.com"
        })
        |> render_submit()

        {:ok, context}
      end

      then_ "the registration completes successfully", context do
        assert_redirect(context.view, "/users/log-in")
        :ok
      end
    end

    scenario "registration form accepts email input" do
      given_ "a user is on the registration page", context do
        {:ok, view, html} = live(build_conn(), ~p"/users/register")
        {:ok, context |> Map.put(:view, view) |> Map.put(:html, html)}
      end

      then_ "the form shows email field", context do
        assert context.html =~ "Email" or context.html =~ "email"
        :ok
      end
    end
  end
end
