defmodule MetricFlowSpex.Criterion33ClientCanSpecifyAccessLevelInInvitationSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Client can specify access level in invitation: read-only, account manager, or admin",
    criterion: 33 do
    scenario "the invitation form offers read-only, account manager, and admin as access levels" do
      given_ :user_logged_in_as_owner

      when_ "the owner opens the invitation form", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/invitations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "read-only, account manager, and admin are all available as access levels", context do
        html = render(context.view)
        assert html =~ ~s(value="read_only")
        assert html =~ ~s(value="account_manager")
        assert html =~ ~s(value="admin")
        {:ok, context}
      end
    end

    scenario "the owner can send an invitation at the admin access level" do
      given_ :user_logged_in_as_owner

      when_ "the owner sends an invitation with the admin access level selected", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/invitations")

        view
        |> form("#invite_member_form",
          invitation: %{
            email: "admin-invite@example.com",
            role: "admin"
          }
        )
        |> render_submit()

        {:ok, Map.put(context, :view, view)}
      end

      then_ "the pending invitation shows the admin access level", context do
        html = render(context.view)
        assert html =~ "admin-invite@example.com"
        assert html =~ "Admin"
        {:ok, context}
      end
    end
  end
end
