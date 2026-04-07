defmodule MetricFlowSpex.ClientCanViewListOfAllUsersWithAccessToTheirAccountSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Client can view list of all users with access to their account" do
    scenario "owner navigates to members page and sees the members list" do
      given_ :user_logged_in_as_owner

      given_ "the owner navigates to the account members page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/members")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the Members heading is displayed", context do
        assert render(context.view) =~ "Members"
        :ok
      end

      then_ "the members list is present on the page", context do
        assert has_element?(context.view, "[data-role='member-row']")
        :ok
      end

      then_ "the owner's own email appears in the list", context do
        assert render(context.view) =~ context.owner_email
        :ok
      end
    end

    scenario "owner sees multiple users after inviting a member" do
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

      then_ "both users appear in the members list", context do
        html = render(context.view)
        assert html =~ context.owner_email
        assert html =~ context.second_user_email
        :ok
      end

      then_ "each user has their own member row", context do
        member_rows =
          context.view
          |> render()
          |> Floki.parse_document!()
          |> Floki.find("[data-role='member-row']")

        assert length(member_rows) >= 2
        :ok
      end
    end

    scenario "unauthenticated user cannot access the members page" do
      given_ "an unauthenticated connection exists", _context do
        conn = build_conn()
        {:ok, %{unauth_conn: conn}}
      end

      then_ "the unauthenticated user is redirected away from the members page", context do
        result = live(context.unauth_conn, "/app/accounts/members")
        assert {:error, {:redirect, %{to: "/users/log-in"}}} = result
        :ok
      end
    end
  end
end
