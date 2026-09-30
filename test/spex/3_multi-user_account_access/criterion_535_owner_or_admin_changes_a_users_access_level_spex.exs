defmodule MetricFlowSpex.OwnerOrAdminChangesAUsersAccessLevelSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Owner or admin changes a user's access level", criterion: 535 do
    scenario "Alex, an admin, changes a read-only teammate to account manager" do
      given_ :user_logged_in_as_owner

      given_ "Alex holds admin access and a teammate holds read-only access", context do
        alex_email = "alex#{System.unique_integer([:positive])}@example.com"
        alex_password = "SecurePassword123!"
        teammate_email = "teammate#{System.unique_integer([:positive])}@example.com"
        teammate_password = "SecurePassword123!"

        for {email, password} <- [{alex_email, alex_password}, {teammate_email, teammate_password}] do
          {:ok, reg_view, _html} = live(build_conn(), "/users/register")

          reg_view
          |> form("#registration_form", user: %{
            email: email,
            password: password,
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

      when_ "Alex changes the teammate's role to account manager", context do
        {:ok, view, _html} = live(context.alex_conn, "/app/accounts/members")

        view
        |> element("[data-role='change-role'][data-user-email='#{context.teammate_email}']")
        |> render_click(%{role: "account_manager"})

        {:ok, Map.put(context, :view, view)}
      end

      then_ "the teammate's access level is updated", context do
        html = render(context.view)
        assert html =~ context.teammate_email
        assert html =~ "account_manager"

        {:ok, context}
      end
    end
  end
end
