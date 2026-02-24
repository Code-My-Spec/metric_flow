defmodule MetricFlowSpex.UsersCanHaveDifferentAccessLevelsSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Users can have different access levels: owner, admin, account manager, read-only" do
    scenario "invite form shows all available role options" do
      given_ :user_logged_in_as_owner

      given_ "the owner is on the members page", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts/members")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the role selector includes all access levels", context do
        html = render(context.view)
        assert html =~ "owner"
        assert html =~ "admin"
        assert html =~ "account_manager"
        assert html =~ "read_only"
        :ok
      end
    end

    scenario "owner can invite a user with admin role" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the owner is on the members page", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts/members")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the owner invites a user as admin", context do
        context.view
        |> form("#invite_member_form", invitation: %{
          email: context.second_user_email,
          role: "admin"
        })
        |> render_submit()

        {:ok, context}
      end

      then_ "the invited user appears with the admin role badge", context do
        html = render(context.view)
        assert html =~ context.second_user_email
        assert html =~ "admin"
        :ok
      end
    end

    scenario "members list displays each user's role" do
      given_ :user_logged_in_as_owner

      given_ "the owner is on the members page", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts/members")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the owner sees their own role as owner", context do
        html = render(context.view)
        assert html =~ context.owner_email
        assert html =~ "owner"
        :ok
      end
    end
  end
end
