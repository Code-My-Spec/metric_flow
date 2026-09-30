defmodule MetricFlowSpex.InvalidCredentialsShowGenericErrorSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Invalid credentials show a generic error without revealing which field was wrong",
    criterion: 524 do
    scenario "a real email with the wrong password shows the same error as an unknown email" do
      given_ :user_registered_with_password

      given_ "the login page is loaded", context do
        {:ok, view, _html} = live(context.conn, "/users/log-in")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "Dana submits her real email with the wrong password", context do
        form =
          form(context.view, "#login_form_password", user: %{
            email: context.registered_email,
            password: "WrongPassword999!"
          })

        render_submit(form)
        wrong_password_conn = follow_trigger_action(form, context.conn)
        {:ok, Map.put(context, :wrong_password_conn, wrong_password_conn)}
      end

      when_ "she then submits an email that doesn't match any account", context do
        {:ok, view, _html} = live(build_conn(), "/users/log-in")

        form =
          form(view, "#login_form_password", user: %{
            email: "nonexistent@example.com",
            password: "SomePassword123!"
          })

        render_submit(form)
        unknown_email_conn = follow_trigger_action(form, build_conn())
        {:ok, Map.put(context, :unknown_email_conn, unknown_email_conn)}
      end

      then_ "both attempts see the same generic invalid-credentials error", context do
        wrong_password_error =
          Phoenix.Flash.get(context.wrong_password_conn.assigns.flash, :error)

        unknown_email_error =
          Phoenix.Flash.get(context.unknown_email_conn.assigns.flash, :error)

        assert wrong_password_error == "Invalid email or password"
        assert unknown_email_error == "Invalid email or password"
        assert wrong_password_error == unknown_email_error

        {:ok, context}
      end
    end
  end
end
