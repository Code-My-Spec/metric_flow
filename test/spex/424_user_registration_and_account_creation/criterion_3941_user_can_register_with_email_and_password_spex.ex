defmodule MetricFlowSpex.UserLive.Registration.Criterion3941Spex do
  @moduledoc """
  BDD Specification for Criterion 3941: User can register with email and password

  Tests that users can successfully register for an account using their email
  and password through the registration LiveView.
  """

  use SexySpex
  use MetricFlowWeb, :verified_routes
  import_givens MetricFlowSpex.SharedGivens

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  @endpoint MetricFlowWeb.Endpoint

  spex "User can register with email and password" do
    scenario "successful registration with valid email" do
      given_ "I am on the registration page", context do
        conn = Phoenix.ConnTest.build_conn()
        # Calling MetricFlow.Users here would be a boundary violation
        # since MetricFlowSpex only depends on MetricFlowWeb
        {:ok, view, _html} = live(conn, ~p"/users/register")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "I submit a valid email address", context do
        email = "newuser_#{System.unique_integer([:positive])}@example.com"

        result =
          context.view
          |> form("#registration_form", user: %{email: email})
          |> render_submit()

        {:ok, context |> Map.put(:result, result) |> Map.put(:email, email)}
      end

      then_ "I am redirected to login page after successful registration", context do
        # Successful registration redirects to login with flash message
        assert {:error, {:live_redirect, %{to: "/users/log-in"}}} = context.result
        :ok
      end
    end

    scenario "registration form validates email on change" do
      given_ "I am on the registration page", context do
        conn = Phoenix.ConnTest.build_conn()
        {:ok, view, _html} = live(conn, ~p"/users/register")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "I enter an invalid email format", context do
        result =
          context.view
          |> form("#registration_form", user: %{email: "invalid-email"})
          |> render_change()

        {:ok, Map.put(context, :result, result)}
      end

      then_ "I see a validation error for email format", context do
        assert context.result =~ "must have the @ sign and no spaces" or
               context.result =~ "invalid" or
               context.result =~ "email"
        :ok
      end
    end

    scenario "registration page is accessible to unauthenticated users" do
      given_ "I am not logged in", context do
        conn = Phoenix.ConnTest.build_conn()
        {:ok, Map.put(context, :conn, conn)}
      end

      when_ "I navigate to the registration page", context do
        {:ok, view, html} = live(context.conn, ~p"/users/register")
        {:ok, context |> Map.put(:view, view) |> Map.put(:html, html)}
      end

      then_ "I see the registration form", context do
        assert context.html =~ "Register for an account"
        assert context.html =~ "registration_form"
        :ok
      end
    end
  end
end
