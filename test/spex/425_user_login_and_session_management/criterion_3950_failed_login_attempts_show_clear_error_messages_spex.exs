defmodule MetricFlowSpex.FailedLoginAttemptsShowClearErrorMessagesSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Failed login attempts show clear error messages" do
    scenario "user submits incorrect password" do
      given_ :user_registered_with_password

      given_ "the login page is loaded", context do
        {:ok, view, _html} = live(context.conn, "/users/log-in")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user submits the correct email but wrong password", context do
        form =
          form(context.view, "#login_form_password", user: %{
            email: context.registered_email,
            password: "WrongPassword999!"
          })

        render_submit(form)
        conn = follow_trigger_action(form, context.conn)
        {:ok, Map.put(context, :result_conn, conn)}
      end

      then_ "the user sees an invalid credentials error", context do
        assert Phoenix.Flash.get(context.result_conn.assigns.flash, :error) ==
                 "Invalid email or password"

        :ok
      end
    end

    scenario "user submits an unregistered email" do
      given_ "the login page is loaded", context do
        {:ok, view, _html} = live(context.conn, "/users/log-in")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user submits an email that does not exist", context do
        form =
          form(context.view, "#login_form_password", user: %{
            email: "nonexistent@example.com",
            password: "SomePassword123!"
          })

        render_submit(form)
        conn = follow_trigger_action(form, context.conn)
        {:ok, Map.put(context, :result_conn, conn)}
      end

      then_ "the user sees the same invalid credentials error", context do
        assert Phoenix.Flash.get(context.result_conn.assigns.flash, :error) ==
                 "Invalid email or password"

        :ok
      end
    end

    scenario "user submits empty credentials" do
      given_ "the login page is loaded", context do
        {:ok, view, _html} = live(context.conn, "/users/log-in")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user submits the form with empty fields", context do
        form =
          form(context.view, "#login_form_password", user: %{
            email: "",
            password: ""
          })

        render_submit(form)
        conn = follow_trigger_action(form, context.conn)
        {:ok, Map.put(context, :result_conn, conn)}
      end

      then_ "the user sees an error message", context do
        assert Phoenix.Flash.get(context.result_conn.assigns.flash, :error) ==
                 "Invalid email or password"

        :ok
      end
    end
  end
end
