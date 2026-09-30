defmodule MetricFlowSpex.AdminCanInviteAnotherAdminSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Admin can invite another admin", criterion: 532 do
    scenario "Alex, an admin, attempts to invite a new user as admin" do
      given_ :user_logged_in_as_owner

      given_ "Alex holds admin access on the account", context do
        alex_email = "alex#{System.unique_integer([:positive])}@example.com"
        alex_password = "SecurePassword123!"

        {:ok, reg_view, _html} = live(build_conn(), "/users/register")

        reg_view
        |> form("#registration_form", user: %{
          email: alex_email,
          password: alex_password,
          account_name: "Alex Personal Account"
        })
        |> render_submit()

        {:ok, owner_members_view, _html} = live(context.owner_conn, "/app/accounts/members")

        owner_members_view
        |> form("#invite_member_form", invitation: %{email: alex_email, role: "admin"})
        |> render_submit()

        {:ok, login_view, _html} = live(build_conn(), "/users/log-in")

        login_form =
          form(login_view, "#login_form_password", user: %{
            email: alex_email,
            password: alex_password,
            remember_me: true
          })

        alex_conn = build_conn() |> then(&submit_form(login_form, &1)) |> recycle()

        {:ok, Map.put(context, :alex_conn, alex_conn)}
      end

      when_ "Alex opens the invite form to add a new admin", context do
        {:ok, view, _html} = live(context.alex_conn, "/app/accounts/members")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the invite form does not offer admin as an assignable role for Alex", context do
        # Confirmed against lib/metric_flow_web/live/account_live/members.ex:
        # invite_roles(:admin) and the Authorization module both deliberately
        # exclude :admin from what an admin may assign ("backend rejects it").
        # This criterion expects an admin to be able to invite another admin;
        # current behavior does not allow it, so document the gap rather than
        # crash on a select value the UI never offers.
        html = render(context.view)

        if html =~ ~r/<option value="admin"/ do
          {:ok, context}
        else
          flunk(
            "Expected an admin to be able to invite another admin, but the invite " <>
              "form's role select does not offer 'admin' to an admin-level inviter " <>
              "(see invite_roles/1 and Authorization.target_role_allowed?/2)"
          )
        end
      end
    end
  end
end
