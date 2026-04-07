defmodule MetricFlowSpex.AccountOwnerCanInviteUsersViaEmailSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Account owner or admin can invite users to their account via email" do
    scenario "owner invites an existing user to their account" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the owner is on the members page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/members")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the owner submits the invite form with the second user's email", context do
        context.view
        |> form("#invite_member_form", invitation: %{
          email: context.second_user_email,
          role: "member"
        })
        |> render_submit()

        {:ok, context}
      end

      then_ "the invited user appears in the members list", context do
        html = render(context.view)
        assert html =~ context.second_user_email
        :ok
      end

      then_ "a success message is displayed", context do
        assert render(context.view) =~ "Member invited successfully"
        :ok
      end
    end

    scenario "owner sees an error when inviting a non-existent email" do
      given_ :user_logged_in_as_owner

      given_ "the owner is on the members page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/members")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the owner submits the invite form with an unknown email", context do
        context.view
        |> form("#invite_member_form", invitation: %{
          email: "nobody@example.com",
          role: "member"
        })
        |> render_submit()

        {:ok, context}
      end

      then_ "an error message is displayed", context do
        assert render(context.view) =~ "User not found"
        :ok
      end
    end

    scenario "invite form is visible to owners and admins" do
      given_ :user_logged_in_as_owner

      given_ "the owner is on the members page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/members")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the invite member form is displayed", context do
        assert has_element?(context.view, "#invite_member_form")
        :ok
      end
    end
  end
end
