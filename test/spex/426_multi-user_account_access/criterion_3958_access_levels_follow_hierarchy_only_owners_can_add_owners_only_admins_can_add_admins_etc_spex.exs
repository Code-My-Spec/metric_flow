defmodule MetricFlowSpex.AccessLevelsFollowHierarchySpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Access levels follow hierarchy: only owners can add owners, only admins can add admins, etc." do
    scenario "owner can invite users at any role level" do
      given_ :user_logged_in_as_owner

      given_ "the owner is on the members page", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts/members")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the role selector includes all roles for an owner", context do
        html = render(context.view)
        assert html =~ "owner"
        assert html =~ "admin"
        assert html =~ "account_manager"
        assert html =~ "read_only"
        :ok
      end
    end

    scenario "regular members cannot see the invite form" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the owner has invited a second user as a read-only member", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts/members")

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
        {:ok, view, _html} = live(member_conn, "/accounts/members")
        {:ok, Map.put(context, :member_view, view)}
      end

      then_ "the invite form is not visible to the read-only member", context do
        refute has_element?(context.member_view, "#invite_member_form")
        :ok
      end

      then_ "the role change controls are not visible", context do
        refute has_element?(context.member_view, "[data-role='change-role']")
        :ok
      end
    end

    scenario "admin cannot invite users at the owner level" do
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

        {:ok, context}
      end

      given_ "the admin logs in and visits the members page", context do
        {:ok, login_view, _html} = live(build_conn(), "/users/log-in")

        login_form =
          form(login_view, "#login_form_password", user: %{
            email: context.second_user_email,
            password: context.second_user_password,
            remember_me: true
          })

        logged_in_conn = submit_form(login_form, build_conn())
        admin_conn = recycle(logged_in_conn)
        {:ok, view, _html} = live(admin_conn, "/accounts/members")
        {:ok, Map.put(context, :admin_view, view)}
      end

      then_ "the admin's role selector does not include owner", context do
        html = render(context.admin_view)
        refute html =~ ~r/option.*owner/
        assert html =~ "admin"
        assert html =~ "account_manager"
        assert html =~ "read_only"
        :ok
      end
    end
  end
end
