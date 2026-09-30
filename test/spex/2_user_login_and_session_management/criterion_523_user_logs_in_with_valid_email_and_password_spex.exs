defmodule MetricFlowSpex.UserLogsInWithValidEmailAndPasswordSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "User logs in with valid email and password", criterion: 523 do
    scenario "Dana logs in with her correct email and password" do
      given_ :user_registered_with_password

      given_ "the login page is loaded", context do
        {:ok, view, _html} = live(context.conn, "/users/log-in")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "Dana submits her correct email and password", context do
        form =
          form(context.view, "#login_form_password", user: %{
            email: context.registered_email,
            password: context.registered_password
          })

        conn = submit_form(form, context.conn)
        {:ok, Map.put(context, :login_conn, conn)}
      end

      then_ "she is logged in and reaches her account", context do
        refute redirected_to(context.login_conn) == "/users/log-in"

        conn = recycle(context.login_conn)
        {:ok, _view, html} = live(conn, "/app/accounts")
        assert html =~ "Accounts"

        {:ok, context}
      end
    end
  end
end
