defmodule MetricFlowSpex.AdminCannotDeleteTheAccountSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Admin cannot delete the account", criterion: 551 do
    scenario "user holding admin access attempts to access account deletion" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "a user holds admin access, not owner", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/members")

        view
        |> form("#invite_member_form", invitation: %{
          email: context.second_user_email,
          role: "admin"
        })
        |> render_submit()

        {:ok, context}
      end

      when_ "they attempt to access or trigger account deletion", context do
        {:ok, login_view, _html} = live(build_conn(), "/users/log-in")

        login_form =
          form(login_view, "#login_form_password", user: %{
            email: context.second_user_email,
            password: context.second_user_password,
            remember_me: true
          })

        logged_in_conn = submit_form(login_form, build_conn())
        admin_conn = recycle(logged_in_conn)
        {:ok, view, _html} = live(admin_conn, "/app/accounts/settings")
        {:ok, Map.put(context, :admin_view, view)}
      end

      then_ "the action is blocked", context do
        refute has_element?(context.admin_view, "[data-role='delete-account']")
        {:ok, context}
      end
    end
  end
end
