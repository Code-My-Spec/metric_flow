defmodule MetricFlowSpex.OnlyAccountOwnerRoleCanAccessDeleteAccountOptionSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Only account owner role can access delete account option" do
    scenario "owner can see the delete account section on settings page" do
      given_ :user_logged_in_as_owner

      given_ "the owner navigates to account settings", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts/settings")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the delete account section is visible", context do
        assert has_element?(context.view, "[data-role='delete-account']")
        :ok
      end
    end

    scenario "admin cannot see the delete account section" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the second user has been invited as an admin", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts/members")

        view
        |> form("#invite_member_form", invitation: %{
          email: context.second_user_email,
          role: "admin"
        })
        |> render_submit()

        {:ok, context}
      end

      given_ "the admin member logs in and visits the settings page", context do
        {:ok, login_view, _html} = live(build_conn(), "/users/log-in")

        login_form =
          form(login_view, "#login_form_password", user: %{
            email: context.second_user_email,
            password: context.second_user_password,
            remember_me: true
          })

        logged_in_conn = submit_form(login_form, build_conn())
        admin_conn = recycle(logged_in_conn)
        {:ok, view, _html} = live(admin_conn, "/accounts/settings")
        {:ok, Map.put(context, :admin_view, view)}
      end

      then_ "the delete account section is not visible to the admin", context do
        refute has_element?(context.admin_view, "[data-role='delete-account']")
        :ok
      end
    end

    scenario "read-only member cannot see the delete account section" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the second user has been invited as read-only", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts/members")

        view
        |> form("#invite_member_form", invitation: %{
          email: context.second_user_email,
          role: "read_only"
        })
        |> render_submit()

        {:ok, context}
      end

      given_ "the read-only member logs in and visits the settings page", context do
        {:ok, login_view, _html} = live(build_conn(), "/users/log-in")

        login_form =
          form(login_view, "#login_form_password", user: %{
            email: context.second_user_email,
            password: context.second_user_password,
            remember_me: true
          })

        logged_in_conn = submit_form(login_form, build_conn())
        member_conn = recycle(logged_in_conn)
        {:ok, view, _html} = live(member_conn, "/accounts/settings")
        {:ok, Map.put(context, :member_view, view)}
      end

      then_ "the delete account section is not visible to the read-only member", context do
        refute has_element?(context.member_view, "[data-role='delete-account']")
        :ok
      end
    end
  end
end
