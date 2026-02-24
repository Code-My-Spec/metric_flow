defmodule MetricFlowSpex.UserCanRegisterWithEmailAndPasswordSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "User can register with email and password" do
    scenario "new user submits valid email and password to create an account" do
      given_ "the registration page is loaded", context do
        {:ok, view, _html} = live(context.conn, "/users/register")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user fills in email and password and submits the form", context do
        context.view
        |> form("#registration_form", user: %{
          email: "newuser@example.com",
          password: "SecurePassword123!",
          account_name: "New User Co"
        })
        |> render_submit()

        {:ok, context}
      end

      then_ "the user sees a confirmation message that an email was sent", context do
        assert render(context.view) =~ "An email was sent to newuser@example.com"
        :ok
      end
    end
  end
end
