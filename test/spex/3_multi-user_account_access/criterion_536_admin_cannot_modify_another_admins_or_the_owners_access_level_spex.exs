defmodule MetricFlowSpex.AdminCannotModifyAnotherAdminsOrTheOwnersAccessLevelSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Admin cannot modify another admin's or the owner's access level", criterion: 536 do
    scenario "Alex, an admin, attempts to change another admin's access level" do
      given_ :user_logged_in_as_owner

      given_ "Alex and Bob both hold admin access", context do
        alex_email = "alex#{System.unique_integer([:positive])}@example.com"
        alex_password = "SecurePassword123!"
        bob_email = "bob#{System.unique_integer([:positive])}@example.com"

        for email <- [alex_email, bob_email] do
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
        |> form("#invite_member_form", invitation: %{email: bob_email, role: "admin"})
        |> render_submit()

        {:ok, login_view, _html} = live(build_conn(), "/users/log-in")

        login_form =
          form(login_view, "#login_form_password", user: %{
            email: alex_email,
            password: alex_password,
            remember_me: true
          })

        alex_conn = build_conn() |> then(&submit_form(login_form, &1)) |> recycle()
        bob_id = MetricFlowTest.UsersFixtures.get_user_by_email(bob_email).id

        {:ok, Map.merge(context, %{alex_conn: alex_conn, bob_email: bob_email, bob_id: bob_id})}
      end

      when_ "Alex attempts to change Bob's access level", context do
        {:ok, view, _html} = live(context.alex_conn, "/app/accounts/members")

        view
        |> element("[data-role='change-role'][data-user-email='#{context.bob_email}']")
        |> render_click(%{role: "read_only"})

        {:ok, Map.put(context, :view, view)}
      end

      then_ "the change is blocked because Bob also holds admin access", context do
        # Scoped to Bob's own row: the role-select in every row always lists
        # "read_only" as an <option>, so a plain substring check on the full
        # page html would pass even when the change actually went through.
        assert has_element?(
                 context.view,
                 "tr[data-role='member-row'][data-user-id='#{context.bob_id}'] span.badge",
                 "admin"
               )

        refute has_element?(
                 context.view,
                 "tr[data-role='member-row'][data-user-id='#{context.bob_id}'] span.badge",
                 "read_only"
               )

        {:ok, context}
      end
    end
  end
end
