defmodule MetricFlowSpex.UserCanLogInWithEmailAndPasswordSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "User can log in with email and password" do
    scenario "registered user logs in with valid email and password" do
      given_ :user_registered_with_password

      given_ "the login page is loaded", context do
        {:ok, view, _html} = live(context.conn, "/users/log-in")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user submits valid email and password", context do
        form =
          form(context.view, "#login_form_password", user: %{
            email: context.registered_email,
            password: context.registered_password,
            remember_me: true
          })

        conn = submit_form(form, context.conn)
        {:ok, Map.put(context, :login_conn, conn)}
      end

      then_ "the user is redirected to the home page", context do
        assert redirected_to(context.login_conn) == "/"
        :ok
      end

      then_ "the user sees a welcome message", context do
        assert Phoenix.Flash.get(context.login_conn.assigns.flash, :info) == "Welcome back!"
        :ok
      end
    end

    scenario "registered user logs in via magic link" do
      given_ :user_registered_with_password

      given_ "the login page is loaded", context do
        {:ok, view, _html} = live(context.conn, "/users/log-in")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user submits their email for a magic link", context do
        {:ok, redirected_view, html} =
          context.view
          |> form("#login_form_magic", user: %{email: context.registered_email})
          |> render_submit()
          |> follow_redirect(context.conn, "/users/log-in")

        {:ok, Map.merge(context, %{redirected_view: redirected_view, result_html: html})}
      end

      then_ "the user sees a message that login instructions were sent", context do
        assert context.result_html =~ "If your email is in our system"
        :ok
      end
    end
  end
end
