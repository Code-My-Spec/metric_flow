defmodule MetricFlowSpex.ClientCanSpecifyAccessLevelInInvitationSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Client can specify access level in invitation: read-only, account manager, or admin" do
    scenario "invite form offers read_only, account_manager, and admin role options" do
      given_ :user_logged_in_as_owner

      given_ "the owner is on the members page", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts/invitations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the role select contains a read_only option", context do
        assert has_element?(context.view, "select[name='invitation[role]'] option[value='read_only']")
        :ok
      end

      then_ "the role select contains an account_manager option", context do
        assert has_element?(context.view, "select[name='invitation[role]'] option[value='account_manager']")
        :ok
      end

      then_ "the role select contains an admin option", context do
        assert has_element?(context.view, "select[name='invitation[role]'] option[value='admin']")
        :ok
      end
    end

    scenario "owner can send an invitation with read_only access level" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the owner is on the members page", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts/invitations")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the owner submits the invite form choosing read_only", context do
        context.view
        |> form("#invite_member_form", invitation: %{
          email: context.second_user_email,
          role: "read_only"
        })
        |> render_submit()

        {:ok, context}
      end

      then_ "a success message confirms the member was invited", context do
        assert render(context.view) =~ "Invitation sent"
        :ok
      end
    end

    scenario "owner can send an invitation with account_manager access level" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the owner is on the members page", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts/invitations")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the owner submits the invite form choosing account_manager", context do
        context.view
        |> form("#invite_member_form", invitation: %{
          email: context.second_user_email,
          role: "account_manager"
        })
        |> render_submit()

        {:ok, context}
      end

      then_ "a success message confirms the member was invited", context do
        assert render(context.view) =~ "Invitation sent"
        :ok
      end
    end

    scenario "owner can send an invitation with admin access level" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the owner is on the members page", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts/invitations")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the owner submits the invite form choosing admin", context do
        context.view
        |> form("#invite_member_form", invitation: %{
          email: context.second_user_email,
          role: "admin"
        })
        |> render_submit()

        {:ok, context}
      end

      then_ "a success message confirms the member was invited", context do
        assert render(context.view) =~ "Invitation sent"
        :ok
      end
    end
  end
end
