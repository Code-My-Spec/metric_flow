defmodule MetricFlowSpex.EachUserHasTheirOwnLoginCredentialsSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Each user has their own login credentials" do
    scenario "two users can register and log in independently" do
      given_ :user_registered_with_password

      given_ "a second user is also registered", context do
        second_email = "second#{System.unique_integer([:positive])}@example.com"
        second_password = "AnotherSecure456!"

        {:ok, view, _html} = live(build_conn(), "/users/register")

        view
        |> form("#registration_form", user: %{
          email: second_email,
          password: second_password,
          account_name: "Second Account"
        })
        |> render_submit()

        {:ok, Map.merge(context, %{second_email: second_email, second_password: second_password})}
      end

      when_ "the first user logs in", context do
        {:ok, view, _html} = live(build_conn(), "/users/log-in")

        form =
          form(view, "#login_form_password", user: %{
            email: context.registered_email,
            password: context.registered_password,
            remember_me: true
          })

        conn = submit_form(form, build_conn())
        {:ok, Map.put(context, :first_user_conn, conn)}
      end

      then_ "the first user is logged in successfully", context do
        assert redirected_to(context.first_user_conn) == "/"
        :ok
      end

      when_ "the second user logs in with different credentials", context do
        {:ok, view, _html} = live(build_conn(), "/users/log-in")

        form =
          form(view, "#login_form_password", user: %{
            email: context.second_email,
            password: context.second_password,
            remember_me: true
          })

        conn = submit_form(form, build_conn())
        {:ok, Map.put(context, :second_user_conn, conn)}
      end

      then_ "the second user is also logged in successfully", context do
        assert redirected_to(context.second_user_conn) == "/"
        :ok
      end
    end

    scenario "one user's credentials do not work for another user" do
      given_ :user_registered_with_password

      given_ "a second user is registered with a different password", context do
        email = "other#{System.unique_integer([:positive])}@example.com"
        password = "DifferentPass789!"

        {:ok, view, _html} = live(build_conn(), "/users/register")

        view
        |> form("#registration_form", user: %{
          email: email,
          password: password,
          account_name: "Other Account"
        })
        |> render_submit()

        {:ok, Map.merge(context, %{other_email: email, other_password: password})}
      end

      when_ "the first user tries to log in with the second user's password", context do
        {:ok, view, _html} = live(build_conn(), "/users/log-in")

        form =
          form(view, "#login_form_password", user: %{
            email: context.registered_email,
            password: context.other_password
          })

        render_submit(form)
        conn = follow_trigger_action(form, build_conn())
        {:ok, Map.put(context, :result_conn, conn)}
      end

      then_ "the login fails with an error", context do
        assert Phoenix.Flash.get(context.result_conn.assigns.flash, :error) ==
                 "Invalid email or password"

        :ok
      end
    end

    scenario "each logged-in user sees their own email in the header" do
      given_ :user_registered_with_password

      given_ "the user is logged in", context do
        {:ok, view, _html} = live(build_conn(), "/users/log-in")

        form =
          form(view, "#login_form_password", user: %{
            email: context.registered_email,
            password: context.registered_password,
            remember_me: true
          })

        logged_in_conn = submit_form(form, build_conn())
        {:ok, Map.put(context, :logged_in_conn, recycle(logged_in_conn))}
      end

      when_ "the user visits the settings page", context do
        {:ok, _view, html} = live(context.logged_in_conn, "/users/settings")
        {:ok, Map.put(context, :page_html, html)}
      end

      then_ "the user sees their own email", context do
        assert context.page_html =~ context.registered_email
        :ok
      end
    end
  end
end
