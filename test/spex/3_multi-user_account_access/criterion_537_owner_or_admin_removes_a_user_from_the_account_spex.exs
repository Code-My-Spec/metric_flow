defmodule MetricFlowSpex.OwnerOrAdminRemovesAUserFromTheAccountSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Owner or admin removes a user from the account", criterion: 537 do
    scenario "Alex, an admin, removes a teammate who no longer needs access" do
      given_ :user_logged_in_as_owner

      given_ "Alex holds admin access and a teammate no longer needs access", context do
        alex_email = "alex#{System.unique_integer([:positive])}@example.com"
        alex_password = "SecurePassword123!"
        teammate_email = "teammate#{System.unique_integer([:positive])}@example.com"

        for email <- [alex_email, teammate_email] do
          {:ok, reg_view, _html} = live(build_conn(), "/users/register")

          reg_view
          |> form("#registration_form", user: %{
            email: email,
            password: alex_password,
            account_name: "Personal Account"
          })
          |> render_submit()
        end

        {:ok, owner_members_view, _html} = live(context.owner_conn, "/app/accounts/members")

        owner_members_view
        |> form("#invite_member_form", invitation: %{email: alex_email, role: "admin"})
        |> render_submit()

        owner_members_view
        |> form("#invite_member_form", invitation: %{email: teammate_email, role: "read_only"})
        |> render_submit()

        {:ok, login_view, _html} = live(build_conn(), "/users/log-in")

        login_form =
          form(login_view, "#login_form_password", user: %{
            email: alex_email,
            password: alex_password,
            remember_me: true
          })

        alex_conn = build_conn() |> then(&submit_form(login_form, &1)) |> recycle()

        {:ok, Map.merge(context, %{alex_conn: alex_conn, teammate_email: teammate_email})}
      end

      when_ "Alex removes the teammate from the account", context do
        {:ok, view, _html} = live(context.alex_conn, "/app/accounts/members")

        view
        |> element("[data-role='remove-member'][data-user-email='#{context.teammate_email}']")
        |> render_click()

        {:ok, Map.put(context, :view, view)}
      end

      then_ "the teammate no longer appears on the members list", context do
        refute render(context.view) =~ context.teammate_email
        {:ok, context}
      end
    end
  end
end
