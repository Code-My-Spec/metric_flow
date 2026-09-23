defmodule MetricFlowSpex.ClientCanRevokeAUserAccessAtAnyTimeSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Client can revoke a user access at any time" do
    scenario "owner removes a member and sees them disappear from the list" do
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

      then_ "the second user appears in the members list before removal", context do
        assert render(context.view) =~ context.second_user_email
        :ok
      end

      when_ "the owner clicks the remove button for the second user", context do
        html =
          context.view
          |> element("[data-role='remove-member'][data-user-email='#{context.second_user_email}']")
          |> render_click()

        {:ok, Map.put(context, :result_html, html)}
      end

      then_ "the second user no longer appears in the members list", context do
        refute render(context.view) =~ context.second_user_email
        :ok
      end

      then_ "a success flash message confirms the member was removed", context do
        assert render(context.view) =~ "Member removed"
        :ok
      end
    end

    scenario "owner sees a remove button for each non-owner member" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the owner invites the second user as a member", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/members")

        view
        |> form("#invite_member_form", invitation: %{
          email: context.second_user_email,
          role: "member"
        })
        |> render_submit()

        {:ok, Map.put(context, :view, view)}
      end

      then_ "a remove button is present for the second user", context do
        assert has_element?(
          context.view,
          "[data-role='remove-member'][data-user-email='#{context.second_user_email}']"
        )
        :ok
      end
    end

    scenario "owner does not see a remove button for themselves as the last owner" do
      given_ :user_logged_in_as_owner

      given_ "the owner navigates to the members page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/members")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "no remove button is shown for the owner's own row", context do
        refute has_element?(
          context.view,
          "[data-role='remove-member'][data-user-email='#{context.owner_email}']"
        )
        :ok
      end
    end
  end
end
