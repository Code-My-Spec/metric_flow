defmodule MetricFlowSpex.UserSessionPersistsAcrossBrowserTabsSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "User session persists across browser tabs" do
    scenario "logged-in user can access authenticated pages in a new tab" do
      given_ :user_registered_with_password

      given_ "the user is logged in", context do
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

      when_ "the user opens the settings page in a new tab", context do
        conn = recycle(context.logged_in_conn)
        {:ok, view, html} = live(conn, "/users/settings")
        {:ok, Map.merge(context, %{settings_view: view, settings_html: html})}
      end

      then_ "the user sees the settings page with their email", context do
        assert context.settings_html =~ "Account Settings"
        assert context.settings_html =~ context.registered_email
        :ok
      end
    end

    scenario "logged-in user can navigate to another authenticated page" do
      given_ :user_registered_with_password

      given_ "the user is logged in", context do
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

      when_ "the user opens the accounts page in another tab", context do
        conn = recycle(context.logged_in_conn)
        {:ok, view, html} = live(conn, "/accounts")
        {:ok, Map.merge(context, %{accounts_view: view, accounts_html: html})}
      end

      then_ "the user is not redirected to login", context do
        assert context.accounts_html =~ "Accounts"
        :ok
      end
    end
  end
end
