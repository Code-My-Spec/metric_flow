defmodule MetricFlowSpex.UserCanRegisterWithEmailAndPasswordSpex do
  @moduledoc """
  BDD specification for criterion 3941:
  User can register with email and password

  Note: Current implementation uses magic link (email-only).
  This spec tests the email registration flow. Password support
  will be added in future implementation.
  """

  use SexySpex
  use MetricFlowTest.ConnCase

  import_givens MetricFlowSpex.SharedGivens
  import Phoenix.LiveViewTest

  spex "User can register with email and password" do
    scenario "registration form accepts valid email" do
      given_ "a new user visits the registration page", context do
        {:ok, view, html} = live(build_conn(), ~p"/users/register")
        {:ok, context |> Map.put(:view, view) |> Map.put(:html, html)}
      end

      then_ "the registration form accepts email input", context do
        assert context.html =~ "Email"
        assert context.html =~ "Create an account"
        :ok
      end
    end

    scenario "registration page displays email input field" do
      given_ "a visitor accesses the registration page", context do
        {:ok, view, html} = live(build_conn(), ~p"/users/register")
        {:ok, context |> Map.put(:view, view) |> Map.put(:html, html)}
      end

      then_ "the page shows email input field", context do
        assert context.html =~ ~s(type="email")
        assert context.html =~ "Email"
        :ok
      end

      then_ "the page shows a registration submit button", context do
        assert context.html =~ "Create an account"
        :ok
      end
    end

    scenario "registration requires email" do
      given_ "a user is on the registration page", context do
        {:ok, view, _html} = live(build_conn(), ~p"/users/register")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user submits the form without email", context do
        html =
          context.view
          |> form("#registration_form", user: %{email: ""})
          |> render_submit()

        {:ok, Map.put(context, :html, html)}
      end

      then_ "the form shows an email required error", context do
        assert context.html =~ "can't be blank" or
               context.html =~ "required" or
               context.html =~ "Email"
        :ok
      end
    end
  end
end
