defmodule MetricFlowSpex.AccountManagerCannotGrantAdminAccessSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Account manager cannot grant admin access", criterion: 533 do
    scenario "a user with account manager access is blocked from sending invitations" do
      given_ :user_logged_in_as_owner

      given_ "a teammate holds account manager access, not admin or owner", context do
        manager_email = "manager#{System.unique_integer([:positive])}@example.com"
        manager_password = "SecurePassword123!"

        {:ok, reg_view, _html} = live(build_conn(), "/users/register")

        reg_view
        |> form("#registration_form", user: %{
          email: manager_email,
          password: manager_password,
          account_name: "Manager Personal Account"
        })
        |> render_submit()

        {:ok, owner_members_view, _html} = live(context.owner_conn, "/app/accounts/members")

        owner_members_view
        |> form("#invite_member_form", invitation: %{email: manager_email, role: "account_manager"})
        |> render_submit()

        {:ok, login_view, _html} = live(build_conn(), "/users/log-in")

        login_form =
          form(login_view, "#login_form_password", user: %{
            email: manager_email,
            password: manager_password,
            remember_me: true
          })

        manager_conn = build_conn() |> then(&submit_form(login_form, &1)) |> recycle()

        {:ok, Map.put(context, :manager_conn, manager_conn)}
      end

      when_ "they attempt to invite someone to the account", context do
        result = live(context.manager_conn, "/app/accounts/invitations")
        {:ok, Map.put(context, :invite_page_result, result)}
      end

      then_ "the action is blocked because their access level is below what is required", context do
        assert {:error, {:redirect, %{to: path}}} = context.invite_page_result
        assert path == "/app/accounts/members"

        {:ok, context}
      end
    end
  end
end
