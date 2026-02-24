defmodule MetricFlowSpex.AccountOwnerOrAdminCanModifyUserAccessLevelsSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Account owner or admin can modify user access levels" do
    scenario "owner changes a member's role from read-only to admin" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "a second user has been invited as read-only", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts/members")

        view
        |> form("#invite_member_form", invitation: %{
          email: context.second_user_email,
          role: "read_only"
        })
        |> render_submit()

        {:ok, Map.put(context, :view, view)}
      end

      when_ "the owner changes the member's role to admin", context do
        context.view
        |> element("[data-role='change-role'][data-user-email='#{context.second_user_email}']")
        |> render_click(%{role: "admin"})

        {:ok, context}
      end

      then_ "the member's role is updated to admin", context do
        html = render(context.view)
        assert html =~ context.second_user_email
        assert html =~ "admin"
        :ok
      end

      then_ "a success message is displayed", context do
        assert render(context.view) =~ "Role updated"
        :ok
      end
    end

    scenario "owner cannot demote the last owner" do
      given_ :user_logged_in_as_owner

      given_ "the owner is on the members page", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts/members")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the owner cannot change their own role when they are the only owner", context do
        refute has_element?(
                 context.view,
                 "[data-role='change-role'][data-user-email='#{context.owner_email}']"
               )

        :ok
      end
    end
  end
end
