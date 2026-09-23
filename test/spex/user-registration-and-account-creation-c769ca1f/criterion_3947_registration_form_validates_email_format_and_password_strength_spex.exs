defmodule MetricFlowSpex.RegistrationFormValidationSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Registration form validates email format and password strength" do
    scenario "invalid email format shows an error" do
      given_ "the registration page is loaded", context do
        {:ok, view, _html} = live(context.conn, "/users/register")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user submits the form with an email missing the @ sign", context do
        context.view
        |> form("#registration_form", user: %{
          email: "invalid-email",
          password: "ValidPassword123!"
        })
        |> render_submit()

        {:ok, context}
      end

      then_ "the user sees an email format validation error", context do
        assert render(context.view) =~ "must have the @ sign and no spaces"
        :ok
      end
    end

    scenario "empty email shows a blank field error" do
      given_ "the registration page is loaded", context do
        {:ok, view, _html} = live(context.conn, "/users/register")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user submits the form with an empty email address", context do
        context.view
        |> form("#registration_form", user: %{
          email: "",
          password: "ValidPassword123!"
        })
        |> render_submit()

        {:ok, context}
      end

      then_ "the user sees a required field error for email", context do
        assert render(context.view) =~ "can&#39;t be blank"
        :ok
      end
    end

    scenario "weak password shows a password strength error" do
      given_ "the registration page is loaded", context do
        {:ok, view, _html} = live(context.conn, "/users/register")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user submits the form with a password that is too short", context do
        context.view
        |> form("#registration_form", user: %{
          email: "user@example.com",
          password: "short"
        })
        |> render_submit()

        {:ok, context}
      end

      then_ "the user sees a password length validation error", context do
        assert render(context.view) =~ "should be at least 12 character"
        :ok
      end
    end

    scenario "empty password shows a blank field error" do
      given_ "the registration page is loaded", context do
        {:ok, view, _html} = live(context.conn, "/users/register")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user submits the form with an empty password", context do
        context.view
        |> form("#registration_form", user: %{
          email: "user@example.com",
          password: ""
        })
        |> render_submit()

        {:ok, context}
      end

      then_ "the user sees a required field error for password", context do
        assert render(context.view) =~ "can&#39;t be blank"
        :ok
      end
    end
  end
end
