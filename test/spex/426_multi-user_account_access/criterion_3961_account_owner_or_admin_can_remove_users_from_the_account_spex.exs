defmodule MetricFlowSpex.AccountOwnerOrAdminCanRemoveUsersSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Account owner or admin can remove users from the account" do
    scenario "owner removes a member from the account" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "a second user has been invited as a member", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/members")

        view
        |> form("#invite_member_form", invitation: %{
          email: context.second_user_email,
          role: "account_manager"
        })
        |> render_submit()

        {:ok, Map.put(context, :view, view)}
      end

      when_ "the owner clicks remove on the member", context do
        context.view
        |> element("[data-role='remove-member'][data-user-email='#{context.second_user_email}']")
        |> render_click()

        {:ok, context}
      end

      then_ "the member is removed from the list", context do
        html = render(context.view)
        refute html =~ context.second_user_email
        :ok
      end

      then_ "a success message is displayed", context do
        assert render(context.view) =~ "Member removed"
        :ok
      end
    end

    scenario "owner cannot remove themselves as the last owner" do
      given_ :user_logged_in_as_owner

      given_ "the owner is on the members page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/members")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the remove button is not shown for the last owner", context do
        refute has_element?(
                 context.view,
                 "[data-role='remove-member'][data-user-email='#{context.owner_email}']"
               )

        :ok
      end
    end

    scenario "read-only members cannot see remove buttons" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "a second user has been invited as read-only", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/members")

        view
        |> form("#invite_member_form", invitation: %{
          email: context.second_user_email,
          role: "read_only"
        })
        |> render_submit()

        {:ok, context}
      end

      given_ "the read-only member logs in and visits the members page", context do
        {:ok, login_view, _html} = live(build_conn(), "/users/log-in")

        login_form =
          form(login_view, "#login_form_password", user: %{
            email: context.second_user_email,
            password: context.second_user_password,
            remember_me: true
          })

        logged_in_conn = submit_form(login_form, build_conn())
        member_conn = recycle(logged_in_conn)
        {:ok, view, _html} = live(member_conn, "/app/accounts/members")
        {:ok, Map.put(context, :member_view, view)}
      end

      then_ "no remove buttons are visible", context do
        refute has_element?(context.member_view, "[data-role='remove-member']")
        :ok
      end
    end
  end
end
