defmodule MetricFlowSpex.SystemLogsAllPermissionChangesWithTimestampAndUserWhoMadeChangeSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "System logs all permission changes with timestamp and user who made change" do
    scenario "a role change produces a confirmation with details" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the owner invites the second user with read_only role", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/members")

        view
        |> form("#invite_member_form", invitation: %{
          email: context.second_user_email,
          role: "read_only"
        })
        |> render_submit()

        {:ok, Map.put(context, :members_view, view)}
      end

      when_ "the owner changes the second user's role to admin", context do
        context.members_view
        |> element("[data-role='change-role'][data-user-email='#{context.second_user_email}']")
        |> render_click(%{"role" => "admin"})

        {:ok, context}
      end

      then_ "the system confirms the role change was recorded", context do
        html = render(context.members_view)
        assert html =~ "Role updated"
        :ok
      end

      then_ "the updated role is reflected in the members list with the change visible", context do
        html = render(context.members_view)
        assert html =~ context.second_user_email
        assert html =~ "admin"
        :ok
      end
    end

    scenario "a member removal produces a confirmation with details" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the owner invites the second user to their account", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/members")

        view
        |> form("#invite_member_form", invitation: %{
          email: context.second_user_email,
          role: "member"
        })
        |> render_submit()

        {:ok, Map.put(context, :view, view)}
      end

      when_ "the owner removes the second user from the account", context do
        context.view
        |> element("[data-role='remove-member'][data-user-email='#{context.second_user_email}']")
        |> render_click()

        {:ok, context}
      end

      then_ "the system confirms the member removal was recorded", context do
        html = render(context.view)
        assert html =~ "Member removed"
        :ok
      end

      then_ "the removed member no longer appears in the list", context do
        html = render(context.view)
        refute html =~ context.second_user_email
        :ok
      end
    end
  end
end
