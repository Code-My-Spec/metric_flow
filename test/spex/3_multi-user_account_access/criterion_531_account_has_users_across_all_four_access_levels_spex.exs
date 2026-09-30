defmodule MetricFlowSpex.AccountHasUsersAcrossAllFourAccessLevelsSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Account has users across all four access levels", criterion: 531 do
    scenario "Alex assigns each of the four access levels to different teammates" do
      given_ :user_logged_in_as_owner

      given_ "three teammates are invited, one at each of the other access levels", context do
        admin_email = "admin#{System.unique_integer([:positive])}@example.com"
        manager_email = "manager#{System.unique_integer([:positive])}@example.com"
        readonly_email = "readonly#{System.unique_integer([:positive])}@example.com"

        # invite_member only attaches an *existing* user to the account
        # (it looks the invitee up by email and errors "User not found"
        # otherwise), so each teammate must register before being invited.
        for email <- [admin_email, manager_email, readonly_email] do
          {:ok, reg_view, _html} = live(build_conn(), "/users/register")

          reg_view
          |> form("#registration_form", user: %{
            email: email,
            password: "SecurePassword123!",
            account_name: "Personal Account"
          })
          |> render_submit()
        end

        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/members")

        for {email, role} <- [
              {admin_email, "admin"},
              {manager_email, "account_manager"},
              {readonly_email, "read_only"}
            ] do
          view
          |> form("#invite_member_form", invitation: %{email: email, role: role})
          |> render_submit()
        end

        {:ok,
         Map.merge(context, %{
           view: view,
           admin_email: admin_email,
           manager_email: manager_email,
           readonly_email: readonly_email
         })}
      end

      then_ "users can be owner, admin, account manager, or read-only", context do
        html = render(context.view)

        assert html =~ context.owner_email
        assert html =~ context.admin_email
        assert html =~ context.manager_email
        assert html =~ context.readonly_email

        assert has_element?(context.view, "tr[data-role='member-row']", context.owner_email)
        assert has_element?(context.view, "tr[data-role='member-row']", context.admin_email)
        assert has_element?(context.view, "tr[data-role='member-row']", context.manager_email)
        assert has_element?(context.view, "tr[data-role='member-row']", context.readonly_email)

        {:ok, context}
      end
    end
  end
end
