defmodule MetricFlowSpex.DuplicateEmailRejectedSpex do
  @moduledoc """
  BDD specification for criterion 3948:
  Duplicate email addresses are rejected with clear error message
  """

  use SexySpex
  use MetricFlowTest.ConnCase

  import_givens MetricFlowSpex.SharedGivens
  import Phoenix.LiveViewTest

  spex "Duplicate email addresses are rejected with clear error message" do
    scenario "attempting to register with an already registered email" do
      given_ "a user has already registered with an email", context do
        {:ok, view, _html} = live(build_conn(), ~p"/users/register")

        email = "duplicate_test_#{System.unique_integer([:positive])}@example.com"

        view
        |> form("#registration_form", user: %{email: email})
        |> render_submit()

        {:ok, Map.put(context, :registered_email, email)}
      end

      when_ "another user attempts to register with the same email", context do
        {:ok, view, _html} = live(build_conn(), ~p"/users/register")

        html =
          view
          |> form("#registration_form", user: %{email: context.registered_email})
          |> render_submit()

        {:ok, context |> Map.put(:view, view) |> Map.put(:html, html)}
      end

      then_ "the form displays a duplicate email error", context do
        assert context.html =~ "has already been taken" or
               context.html =~ "already" or
               context.html =~ "exists" or
               context.html =~ "taken" or
               context.html =~ "in use"
        :ok
      end
    end

    scenario "error message is user-friendly for duplicate email" do
      given_ "a user has already registered", context do
        {:ok, view, _html} = live(build_conn(), ~p"/users/register")

        email = "friendly_error_#{System.unique_integer([:positive])}@example.com"

        view
        |> form("#registration_form", user: %{email: email})
        |> render_submit()

        {:ok, Map.put(context, :email, email)}
      end

      when_ "registration is attempted with that email again", context do
        {:ok, view, _html} = live(build_conn(), ~p"/users/register")

        html =
          view
          |> form("#registration_form", user: %{email: context.email})
          |> render_submit()

        {:ok, Map.put(context, :html, html)}
      end

      then_ "the error message helps the user understand the issue", context do
        refute context.html =~ "constraint"
        refute context.html =~ "unique_violation"
        assert context.html =~ "taken" or
               context.html =~ "already" or
               context.html =~ "exists"
        :ok
      end
    end

    scenario "unique email is accepted" do
      given_ "a user registers with a unique email", context do
        {:ok, view, _html} = live(build_conn(), ~p"/users/register")
        unique_email = "unique_#{System.unique_integer([:positive])}@example.com"

        view
        |> form("#registration_form", user: %{email: unique_email})
        |> render_submit()

        assert_redirect(view, "/users/log-in")
        {:ok, Map.put(context, :registered, true)}
      end

      then_ "registration proceeds without duplicate error", context do
        assert context.registered == true
        :ok
      end
    end
  end
end
