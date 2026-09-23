defmodule MetricFlowSpex.DuplicateEmailRejectedSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Duplicate email addresses are rejected with clear error message" do
    scenario "second registration with the same email is rejected" do
      given_ "a user has already registered with an email address", context do
        conn = build_conn()
        {:ok, view, _html} = live(conn, "/users/register")

        view
        |> form("#registration_form", user: %{
          email: "taken@example.com",
          password: "SecurePassword123!",
          account_name: "Taken Co"
        })
        |> render_submit()

        {:ok, context}
      end

      given_ "a new registration form is opened", context do
        {:ok, view, _html} = live(context.conn, "/users/register")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a second user tries to register with the same email address", context do
        context.view
        |> form("#registration_form", user: %{
          email: "taken@example.com",
          password: "AnotherSecurePass456!",
          account_name: "Another Co"
        })
        |> render_submit()

        {:ok, context}
      end

      then_ "the user sees an error that the email has already been taken", context do
        assert render(context.view) =~ "has already been taken"
        :ok
      end
    end

    scenario "duplicate email error is shown inline on the form" do
      given_ "a user has already registered with an email address", context do
        conn = build_conn()
        {:ok, view, _html} = live(conn, "/users/register")

        view
        |> form("#registration_form", user: %{
          email: "duplicate@example.com",
          password: "SecurePassword123!",
          account_name: "Duplicate Co"
        })
        |> render_submit()

        {:ok, context}
      end

      given_ "a new registration form is opened", context do
        {:ok, view, _html} = live(context.conn, "/users/register")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user submits the form with the duplicate email", context do
        context.view
        |> form("#registration_form", user: %{
          email: "duplicate@example.com",
          password: "AnotherSecurePass456!",
          account_name: "Another Dup Co"
        })
        |> render_submit()

        {:ok, context}
      end

      then_ "the error message is visible in the rendered form HTML", context do
        html = render(context.view)
        assert html =~ "has already been taken"
        assert has_element?(context.view, "#registration_form")
        :ok
      end
    end
  end
end
