defmodule MetricFlowSpex.RememberMeExtendsSessionPastDefaultTimeoutSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  @remember_me_cookie "_metric_flow_web_user_remember_me"

  spex "Remember me extends the session past the default timeout", criterion: 528 do
    scenario "Dana remains logged in in a new browsing session after checking Remember me" do
      given_ :user_registered_with_password

      given_ "Dana logs in and checks Remember me", context do
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

      when_ "the default session timeout period passes with no activity", context do
        # The plain browser-session cookie doesn't survive this; only the
        # persistent Remember me cookie does. Carrying just that cookie into
        # a brand-new conn is what "a new browsing session, later" looks like.
        remember_me_value = context.logged_in_conn.resp_cookies[@remember_me_cookie].value

        new_session_conn =
          build_conn()
          |> put_req_cookie(@remember_me_cookie, remember_me_value)

        {:ok, Map.put(context, :new_session_conn, new_session_conn)}
      end

      then_ "Dana remains logged in", context do
        {:ok, _view, html} = live(context.new_session_conn, "/app/accounts")
        assert html =~ "Accounts"
        {:ok, context}
      end
    end
  end
end
