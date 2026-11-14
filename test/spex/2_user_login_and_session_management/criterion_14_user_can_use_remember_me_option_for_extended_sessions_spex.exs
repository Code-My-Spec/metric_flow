defmodule MetricFlowSpex.UserCanUseRememberMeOptionForExtendedSessionsSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Login persists by default without session-duration choices", criterion: 14 do
    scenario "login page defaults to a persistent session" do
      given_ "the login page is loaded", context do
        {:ok, view, _html} = live(context.conn, "/users/log-in")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the form carries the persistent default without visible duration choices", context do
        assert has_element?(
                 context.view,
                 "#login_form_password input[type=hidden][name='user[remember_me]'][value=true]"
               )

        refute has_element?(
                 context.view,
                 "#login_form_password input[name='user[remember_me]']:not([type=hidden])"
               )

        refute has_element?(context.view, "#login_form_magic")
        {:ok, context}
      end
    end

    scenario "user logs in with persistent session by default" do
      given_(:user_registered_with_password)

      given_ "the login page is loaded", context do
        {:ok, view, _html} = live(context.conn, "/users/log-in")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user submits credentials with remember me", context do
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

      then_ "the user is successfully logged in", context do
        assert redirected_to(context.login_conn) == "/app/chat"
        {:ok, context}
      end

      then_ "the remember me cookie is set", context do
        assert context.login_conn.resp_cookies["_metric_flow_web_user_remember_me"]
        {:ok, context}
      end
    end

    scenario "backend login without the persistent flag uses a shorter session" do
      given_(:user_registered_with_password)

      when_ "the user submits credentials directly without remember me", context do
        conn =
          Phoenix.ConnTest.post(context.conn, "/users/log-in", %{
            "user" => %{
              "email" => context.registered_email,
              "password" => context.registered_password
            }
          })

        {:ok, Map.put(context, :login_conn, conn)}
      end

      then_ "the user is successfully logged in", context do
        assert redirected_to(context.login_conn) == "/app/chat"
        {:ok, context}
      end

      then_ "no remember me cookie is set", context do
        refute context.login_conn.resp_cookies["_metric_flow_web_user_remember_me"]
        {:ok, context}
      end
    end
  end
end
