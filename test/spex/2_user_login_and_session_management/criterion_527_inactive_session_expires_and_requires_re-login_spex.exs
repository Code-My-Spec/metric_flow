defmodule MetricFlowSpex.InactiveSessionExpiresAndRequiresReLoginSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Inactive session expires and requires re-login", criterion: 527 do
    scenario "Dana returns in a new browsing session after logging in without Remember me" do
      given_ :user_registered_with_password

      given_ "Dana logged in without choosing Remember me", context do
        {:ok, view, _html} = live(context.conn, "/users/log-in")

        form =
          form(view, "#login_form_password", user: %{
            email: context.registered_email,
            password: context.registered_password
          })

        logged_in_conn = submit_form(form, context.conn)
        {:ok, Map.put(context, :logged_in_conn, logged_in_conn)}
      end

      when_ "she returns to the app in a new browsing session", context do
        # Without Remember me, only the browser-session cookie holds the
        # login — a real browser drops it once the browser session ends, so
        # a fresh, cookie-less conn is what "has been inactive past the
        # session timeout" looks like here.
        {:ok, Map.put(context, :new_session_conn, build_conn())}
      end

      then_ "her session has expired and she must log in again", context do
        assert {:error, {:redirect, %{to: path}}} =
                 live(context.new_session_conn, "/app/accounts")

        assert path =~ "/users/log-in"
        {:ok, context}
      end
    end
  end
end
