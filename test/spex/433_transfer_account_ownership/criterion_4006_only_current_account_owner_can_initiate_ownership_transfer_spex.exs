defmodule MetricFlowSpex.OnlyCurrentAccountOwnerCanInitiateOwnershipTransferSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Only current account owner can initiate ownership transfer" do
    scenario "owner sees the transfer ownership section on the settings page" do
      given_ :user_logged_in_as_owner

      given_ "the owner navigates to account settings", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts/settings")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the Transfer Ownership section is visible", context do
        assert has_element?(context.view, "[data-role='transfer-ownership']")
        :ok
      end

      then_ "the Transfer Ownership button is present", context do
        assert render(context.view) =~ "Transfer Ownership"
        :ok
      end
    end

    scenario "non-owner member does not see the transfer ownership section" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the second user has been added as admin", context do
        {:ok, members_view, _html} = live(context.owner_conn, "/accounts/members")

        members_view
        |> form("#invite_member_form", invitation: %{
          email: context.second_user_email,
          role: "admin"
        })
        |> render_submit()

        {:ok, context}
      end

      given_ "the second user logs in", context do
        login_conn = build_conn()
        {:ok, login_view, _html} = live(login_conn, "/users/log-in")

        login_form =
          form(login_view, "#login_form_password", user: %{
            email: context.second_user_email,
            password: context.second_user_password,
            remember_me: true
          })

        logged_in_conn = submit_form(login_form, login_conn)
        member_conn = recycle(logged_in_conn)
        {:ok, Map.put(context, :member_conn, member_conn)}
      end

      given_ "the member navigates to account settings", context do
        {:ok, view, _html} = live(context.member_conn, "/accounts/settings")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the Transfer Ownership section is not visible to the non-owner", context do
        refute has_element?(context.view, "[data-role='transfer-ownership']")
        :ok
      end
    end
  end
end
