defmodule MetricFlowSpex.UserCanLogInWithEmailAndPasswordSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "User can log in with email and password", criterion: 9 do
    scenario "registered user logs in with valid email and password" do
      given_(:user_registered_with_password)

      given_ "the login page is loaded", context do
        {:ok, view, _html} = live(context.conn, "/users/log-in")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user submits valid email and password", context do
        form =
          form(context.view, "#login_form_password",
            user: %{
              email: context.registered_email,
              password: context.registered_password,
              remember_me: true
            }
          )

        conn = submit_form(form, context.conn)
        {:ok, Map.put(context, :login_conn, conn)}
      end

      then_ "the user is redirected to the AI chat home", context do
        assert redirected_to(context.login_conn) == "/app/chat"
        {:ok, context}
      end

      then_ "the user sees a welcome message", context do
        assert Phoenix.Flash.get(context.login_conn.assigns.flash, :info) == "Welcome back!"
        {:ok, context}
      end
    end

    scenario "login page offers one email and password form with recovery" do
      given_ "the login page is loaded", context do
        {:ok, view, _html} = live(context.conn, "/users/log-in")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "one primary email and password form is shown", context do
        assert has_element?(context.view, "#login_form_password input[type=email]")
        assert has_element?(context.view, "#login_form_password input[type=password]")
        refute has_element?(context.view, "#login_form_magic")
        refute has_element?(context.view, "form:not(#login_form_password) input[type=email]")
        {:ok, context}
      end

      then_ "password recovery and registration are available", context do
        assert has_element?(context.view, "#forgot-password-link[href='/users/forgot-password']")
        assert has_element?(context.view, "#register-link[href='/users/register']")
        {:ok, context}
      end
    end
  end
end
