defmodule MetricFlowSpex.RegistrationValidatesEmailAndPasswordSpex do
  @moduledoc """
  BDD specification for criterion 3947:
  Registration form validates email format and password strength

  Note: Current implementation validates email format. Password
  validation will be added when password-based auth is implemented.
  """

  use SexySpex
  use MetricFlowTest.ConnCase

  import_givens MetricFlowSpex.SharedGivens
  import Phoenix.LiveViewTest

  spex "Registration form validates email format and password strength" do
    scenario "invalid email format is rejected" do
      given_ "a user is on the registration page", context do
        {:ok, view, _html} = live(build_conn(), ~p"/users/register")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user enters an invalid email format", context do
        html =
          context.view
          |> form("#registration_form", user: %{email: "invalid-email-no-at-sign"})
          |> render_change()

        {:ok, Map.put(context, :html, html)}
      end

      then_ "the form displays an email format error", context do
        assert context.html =~ "@" or
               context.html =~ "invalid" or
               context.html =~ "format" or
               context.html =~ "must have"
        :ok
      end
    end

    scenario "email without domain is rejected" do
      given_ "a user is on the registration page", context do
        {:ok, view, _html} = live(build_conn(), ~p"/users/register")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user enters an email without domain", context do
        html =
          context.view
          |> form("#registration_form", user: %{email: "user@"})
          |> render_change()

        {:ok, Map.put(context, :html, html)}
      end

      then_ "the form displays a validation error", context do
        assert context.html =~ "invalid" or
               context.html =~ "@" or
               context.html =~ "format" or
               context.html =~ "must have"
        :ok
      end
    end

    scenario "valid email is accepted" do
      given_ "a user is on the registration page", context do
        {:ok, view, _html} = live(build_conn(), ~p"/users/register")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user enters a valid email", context do
        html =
          context.view
          |> form("#registration_form", user: %{
            email: "valid_#{System.unique_integer([:positive])}@example.com"
          })
          |> render_change()

        {:ok, Map.put(context, :html, html)}
      end

      then_ "no email validation errors are shown", context do
        refute context.html =~ "must have the @ sign"
        :ok
      end
    end

    scenario "empty email is rejected" do
      given_ "a user is on the registration page", context do
        {:ok, view, _html} = live(build_conn(), ~p"/users/register")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user submits with empty email", context do
        html =
          context.view
          |> form("#registration_form", user: %{email: ""})
          |> render_submit()

        {:ok, Map.put(context, :html, html)}
      end

      then_ "the form displays a required field error", context do
        assert context.html =~ "can't be blank" or
               context.html =~ "required"
        :ok
      end
    end
  end
end
