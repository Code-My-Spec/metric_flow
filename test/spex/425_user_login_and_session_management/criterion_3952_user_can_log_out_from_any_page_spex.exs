defmodule MetricFlowSpex.UserCanLogOutFromAnyPageSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "User can log out from any page" do
    scenario "logged-in user sees log out link and can log out from settings" do
      given_ :user_registered_with_password

      given_ "the user is logged in and on the settings page", context do
        {:ok, view, _html} = live(context.conn, "/users/log-in")

        form =
          form(view, "#login_form_password", user: %{
            email: context.registered_email,
            password: context.registered_password,
            remember_me: true
          })

        logged_in_conn = submit_form(form, context.conn)
        conn = recycle(logged_in_conn)
        {:ok, _settings_view, html} = live(conn, "/users/settings")
        {:ok, Map.merge(context, %{settings_html: html, logged_in_conn: conn})}
      end

      then_ "the user sees a log out link on the page", context do
        assert context.settings_html =~ "Log out"
        :ok
      end

      when_ "the user clicks the log out link", context do
        conn =
          context.logged_in_conn
          |> recycle()
          |> delete("/users/log-out")

        {:ok, Map.put(context, :logout_conn, conn)}
      end

      then_ "the user is redirected to the home page", context do
        assert redirected_to(context.logout_conn) == "/"
        :ok
      end

      then_ "the user sees a logged out confirmation", context do
        assert Phoenix.Flash.get(context.logout_conn.assigns.flash, :info) ==
                 "Logged out successfully."

        :ok
      end
    end

    scenario "after logging out the user cannot access authenticated pages" do
      given_ :user_registered_with_password

      given_ "the user logs in then logs out", context do
        {:ok, view, _html} = live(context.conn, "/users/log-in")

        form =
          form(view, "#login_form_password", user: %{
            email: context.registered_email,
            password: context.registered_password,
            remember_me: true
          })

        logged_in_conn = submit_form(form, context.conn)

        logout_conn =
          logged_in_conn
          |> recycle()
          |> delete("/users/log-out")

        {:ok, Map.put(context, :logout_conn, logout_conn)}
      end

      when_ "the user tries to access the settings page", context do
        conn =
          context.logout_conn
          |> recycle()

        {:ok, Map.put(context, :after_logout_conn, conn)}
      end

      then_ "the user is redirected to the login page", context do
        {:error, {:redirect, %{to: path}}} = live(context.after_logout_conn, "/users/settings")
        assert path =~ "/users/log-in"
        :ok
      end
    end
  end
end
