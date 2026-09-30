defmodule MetricFlowSpex.UserLogsOutFromAnyPageSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "User logs out from any page", criterion: 526 do
    scenario "Dana logs out while viewing the accounts page" do
      given_ :user_registered_with_password

      given_ "Dana is logged in and viewing the accounts page", context do
        {:ok, view, _html} = live(context.conn, "/users/log-in")

        form =
          form(view, "#login_form_password", user: %{
            email: context.registered_email,
            password: context.registered_password,
            remember_me: true
          })

        logged_in_conn = submit_form(form, context.conn)
        conn = recycle(logged_in_conn)
        {:ok, _accounts_view, html} = live(conn, "/app/accounts")
        {:ok, Map.merge(context, %{accounts_html: html, logged_in_conn: conn})}
      end

      then_ "she sees a log out control on the page", context do
        assert context.accounts_html =~ "Log out"
        {:ok, context}
      end

      when_ "she clicks log out", context do
        conn =
          context.logged_in_conn
          |> recycle()
          |> delete("/users/log-out")

        {:ok, Map.put(context, :logout_conn, conn)}
      end

      then_ "her session ends and she is logged out", context do
        assert redirected_to(context.logout_conn) == "/users/log-in"

        after_logout_conn = recycle(context.logout_conn)
        assert {:error, {:redirect, %{to: path}}} = live(after_logout_conn, "/app/accounts")
        assert path =~ "/users/log-in"

        {:ok, context}
      end
    end
  end
end
