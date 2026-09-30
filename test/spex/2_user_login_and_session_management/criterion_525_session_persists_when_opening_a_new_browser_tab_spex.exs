defmodule MetricFlowSpex.SessionPersistsWhenOpeningNewBrowserTabSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Session persists when opening a new browser tab", criterion: 525 do
    scenario "Dana stays logged in when she opens the app in a new tab" do
      given_ :user_registered_with_password

      given_ "Dana is logged in", context do
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

      when_ "she opens the app in a new browser tab", context do
        new_tab_conn = recycle(context.logged_in_conn)
        {:ok, Map.put(context, :new_tab_conn, new_tab_conn)}
      end

      then_ "she is still logged in in the new tab", context do
        {:ok, _view, html} = live(context.new_tab_conn, "/app/accounts")
        assert html =~ "Accounts"
        {:ok, context}
      end
    end
  end
end
