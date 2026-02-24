defmodule MetricFlowSpex.UserCanUseRememberMeOptionForExtendedSessionsSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "User can use Remember me option for extended sessions" do
    scenario "login page shows remember me option" do
      given_ "the login page is loaded", context do
        {:ok, _view, html} = live(context.conn, "/users/log-in")
        {:ok, Map.put(context, :login_html, html)}
      end

      then_ "the user sees both login options", context do
        assert context.login_html =~ "Log in and stay logged in"
        assert context.login_html =~ "Log in only this time"
        :ok
      end
    end

    scenario "user logs in with remember me enabled" do
      given_ :user_registered_with_password

      given_ "the login page is loaded", context do
        {:ok, view, _html} = live(context.conn, "/users/log-in")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user submits credentials with remember me", context do
        form =
          form(context.view, "#login_form_password", user: %{
            email: context.registered_email,
            password: context.registered_password,
            remember_me: true
          })

        conn = submit_form(form, context.conn)
        {:ok, Map.put(context, :login_conn, conn)}
      end

      then_ "the user is successfully logged in", context do
        assert redirected_to(context.login_conn) == "/"
        :ok
      end

      then_ "the remember me cookie is set", context do
        assert context.login_conn.resp_cookies["_metric_flow_web_user_remember_me"]
        :ok
      end
    end

    scenario "user logs in without remember me" do
      given_ :user_registered_with_password

      given_ "the login page is loaded", context do
        {:ok, view, _html} = live(context.conn, "/users/log-in")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user submits credentials without remember me", context do
        form =
          form(context.view, "#login_form_password", user: %{
            email: context.registered_email,
            password: context.registered_password
          })

        conn = submit_form(form, context.conn)
        {:ok, Map.put(context, :login_conn, conn)}
      end

      then_ "the user is successfully logged in", context do
        assert redirected_to(context.login_conn) == "/"
        :ok
      end

      then_ "no remember me cookie is set", context do
        refute context.login_conn.resp_cookies["_metric_flow_web_user_remember_me"]
        :ok
      end
    end
  end
end
