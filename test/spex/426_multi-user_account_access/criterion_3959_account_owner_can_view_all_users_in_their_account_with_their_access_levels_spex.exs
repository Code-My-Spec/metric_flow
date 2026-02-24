defmodule MetricFlowSpex.AccountOwnerCanViewAllUsersWithAccessLevelsSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Account owner can view all users in their account with their access levels" do
    scenario "owner sees themselves listed as owner on the members page" do
      given_ :user_logged_in_as_owner

      given_ "the owner navigates to the members page", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts/members")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the owner sees their own email in the members list", context do
        html = render(context.view)
        assert html =~ context.owner_email
        :ok
      end

      then_ "the owner's role is displayed as owner", context do
        html = render(context.view)
        assert html =~ "owner"
        :ok
      end
    end

    scenario "owner sees all invited members with their roles" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the owner has invited a second user as admin", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts/members")

        view
        |> form("#invite_member_form", invitation: %{
          email: context.second_user_email,
          role: "admin"
        })
        |> render_submit()

        {:ok, Map.put(context, :view, view)}
      end

      then_ "the members list shows both the owner and the invited user", context do
        html = render(context.view)
        assert html =~ context.owner_email
        assert html =~ context.second_user_email
        :ok
      end

      then_ "each member's role is displayed", context do
        html = render(context.view)
        assert html =~ "owner"
        assert html =~ "admin"
        :ok
      end
    end

    scenario "members page shows member information" do
      given_ :user_logged_in_as_owner

      given_ "the owner navigates to the members page", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts/members")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page header shows Members", context do
        html = render(context.view)
        assert html =~ "Members"
        :ok
      end

      then_ "each member row has a member data role", context do
        assert has_element?(context.view, "[data-role='member']")
        :ok
      end
    end
  end
end
