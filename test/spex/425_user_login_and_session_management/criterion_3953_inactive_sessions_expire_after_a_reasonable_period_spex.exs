defmodule MetricFlowSpex.InactiveSessionsExpireAfterReasonablePeriodSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Inactive sessions expire after a reasonable period" do
    scenario "user with no session is redirected to login when accessing protected pages" do
      given_ "the user has no active session", context do
        {:ok, context}
      end

      when_ "the user tries to access the settings page", context do
        {:error, {:redirect, redirect}} = live(context.conn, "/users/settings")
        {:ok, Map.put(context, :redirect, redirect)}
      end

      then_ "the user is redirected to the login page", context do
        assert context.redirect.to =~ "/users/log-in"
        :ok
      end
    end

    scenario "user is shown a message to log in when session is missing" do
      given_ "the user has no active session", context do
        {:ok, context}
      end

      when_ "the user tries to access the settings page and follows the redirect", context do
        {:error, {:redirect, %{to: path, flash: flash}}} =
          live(context.conn, "/users/settings")

        {:ok, Map.merge(context, %{redirect_path: path, flash: flash})}
      end

      then_ "the user sees a message to log in", context do
        assert context.flash["error"] == "You must log in to access this page."
        :ok
      end

      then_ "the redirect points to the login page", context do
        assert context.redirect_path == "/users/log-in"
        :ok
      end
    end

    scenario "user with valid session can access protected pages" do
      given_ :user_registered_with_password

      given_ "the user has an active session", context do
        {:ok, view, _html} = live(context.conn, "/users/log-in")

        form =
          form(view, "#login_form_password", user: %{
            email: context.registered_email,
            password: context.registered_password,
            remember_me: true
          })

        logged_in_conn = submit_form(form, context.conn)
        {:ok, Map.put(context, :logged_in_conn, logged_in_conn)}
      end

      when_ "the user accesses the settings page", context do
        conn = recycle(context.logged_in_conn)
        {:ok, _view, html} = live(conn, "/users/settings")
        {:ok, Map.put(context, :settings_html, html)}
      end

      then_ "the user sees the settings page", context do
        assert context.settings_html =~ "Account Settings"
        :ok
      end
    end
  end
end
