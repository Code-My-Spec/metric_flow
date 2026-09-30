defmodule MetricFlowSpex.RegisteringWithEmailAlreadyInUseIsRejectedSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  spex "Registering with an email already in use is rejected", criterion: 522 do
    scenario "a second registration attempt with the same email is rejected with a clear message" do
      given_ "an account already exists with a given email address", context do
        conn = build_conn()
        {:ok, view, _html} = live(conn, "/users/register")

        view
        |> form("#registration_form", user: %{
          email: "already_used@example.com",
          password: "SecurePassword123!",
          account_name: "Already Used Co"
        })
        |> render_submit()

        {:ok, context}
      end

      when_ "a new user attempts to register with that same email", context do
        {:ok, view, _html} = live(context.conn, "/users/register")

        view
        |> form("#registration_form", user: %{
          email: "already_used@example.com",
          password: "AnotherSecurePass456!",
          account_name: "Second Attempt Co"
        })
        |> render_submit()

        {:ok, Map.put(context, :view, view)}
      end

      then_ "registration is rejected with a clear duplicate-email error message", context do
        assert render(context.view) =~ "has already been taken"
        {:ok, context}
      end
    end
  end
end
