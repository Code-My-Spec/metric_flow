defmodule MetricFlowSpex.ClientCanModifyAUserAccessLevelToUpgradeOrDowngradePermissionsSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Client can modify a user access level to upgrade or downgrade permissions" do
    scenario "owner upgrades a member's role from read_only to admin" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the owner invites the second user with read_only role", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts/members")

        view
        |> form("#invite_member_form", invitation: %{
          email: context.second_user_email,
          role: "read_only"
        })
        |> render_submit()

        {:ok, Map.put(context, :members_view, view)}
      end

      when_ "the owner changes the second user's role to admin", context do
        html =
          context.members_view
          |> element("[data-role='change-role'][data-user-email='#{context.second_user_email}']")
          |> render_click(%{"role" => "admin"})

        {:ok, Map.put(context, :result_html, html)}
      end

      then_ "a role updated confirmation message is displayed", context do
        assert render(context.members_view) =~ "Role updated"
        :ok
      end

      then_ "the second user's role now shows as admin in the members list", context do
        html = render(context.members_view)
        assert html =~ context.second_user_email
        assert html =~ "admin"
        :ok
      end
    end

    scenario "owner downgrades a member's role from admin to read_only" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the owner invites the second user with admin role", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts/members")

        view
        |> form("#invite_member_form", invitation: %{
          email: context.second_user_email,
          role: "admin"
        })
        |> render_submit()

        {:ok, Map.put(context, :members_view, view)}
      end

      when_ "the owner changes the second user's role to read_only", context do
        html =
          context.members_view
          |> element("[data-role='change-role'][data-user-email='#{context.second_user_email}']")
          |> render_click(%{"role" => "read_only"})

        {:ok, Map.put(context, :result_html, html)}
      end

      then_ "a role updated confirmation message is displayed", context do
        assert render(context.members_view) =~ "Role updated"
        :ok
      end

      then_ "the second user's role now shows as read_only in the members list", context do
        html = render(context.members_view)
        assert html =~ context.second_user_email
        assert html =~ "read_only"
        :ok
      end
    end

    scenario "owner uses the role select dropdown to change a member's role" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the owner invites the second user with read_only role", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts/members")

        view
        |> form("#invite_member_form", invitation: %{
          email: context.second_user_email,
          role: "read_only"
        })
        |> render_submit()

        {:ok, Map.put(context, :members_view, view)}
      end

      when_ "the owner selects account_manager from the role dropdown for the second user", context do
        html =
          context.members_view
          |> element("[data-role='change-role'][data-user-email='#{context.second_user_email}']")
          |> render_click(%{"role" => "account_manager"})

        {:ok, Map.put(context, :result_html, html)}
      end

      then_ "a role updated confirmation message is displayed", context do
        assert render(context.members_view) =~ "Role updated"
        :ok
      end

      then_ "the updated role is reflected in the members list", context do
        assert render(context.members_view) =~ "account_manager"
        :ok
      end
    end
  end
end
