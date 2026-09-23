defmodule MetricFlowSpex.AdminAndOtherRolesCannotDeleteAccountSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Admin and other roles cannot delete account" do
    scenario "admin member does not see delete account section" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the owner invites the second user as admin", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/members")

        view
        |> form("#invite_member_form", invitation: %{
          email: context.second_user_email,
          role: "admin"
        })
        |> render_submit()

        {:ok, context}
      end

      given_ "the admin member logs in and visits account settings", context do
        {:ok, login_view, _html} = live(build_conn(), "/users/log-in")

        login_form =
          form(login_view, "#login_form_password", user: %{
            email: context.second_user_email,
            password: context.second_user_password,
            remember_me: true
          })

        logged_in_conn = submit_form(login_form, build_conn())
        member_conn = recycle(logged_in_conn)
        {:ok, view, _html} = live(member_conn, "/app/accounts/settings")
        {:ok, Map.put(context, :member_view, view)}
      end

      then_ "the admin does not see the delete account section", context do
        refute has_element?(context.member_view, "[data-role='delete-account']")
        :ok
      end
    end

    scenario "account manager does not see delete account section" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the owner invites the second user as account manager", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/members")

        view
        |> form("#invite_member_form", invitation: %{
          email: context.second_user_email,
          role: "account_manager"
        })
        |> render_submit()

        {:ok, context}
      end

      given_ "the account manager logs in and visits account settings", context do
        {:ok, login_view, _html} = live(build_conn(), "/users/log-in")

        login_form =
          form(login_view, "#login_form_password", user: %{
            email: context.second_user_email,
            password: context.second_user_password,
            remember_me: true
          })

        logged_in_conn = submit_form(login_form, build_conn())
        member_conn = recycle(logged_in_conn)
        {:ok, view, _html} = live(member_conn, "/app/accounts/settings")
        {:ok, Map.put(context, :member_view, view)}
      end

      then_ "the account manager does not see the delete account section", context do
        refute has_element?(context.member_view, "[data-role='delete-account']")
        :ok
      end
    end

    scenario "read-only member does not see delete account section" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the owner invites the second user as read-only", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/members")

        view
        |> form("#invite_member_form", invitation: %{
          email: context.second_user_email,
          role: "read_only"
        })
        |> render_submit()

        {:ok, context}
      end

      given_ "the read-only member logs in and visits account settings", context do
        {:ok, login_view, _html} = live(build_conn(), "/users/log-in")

        login_form =
          form(login_view, "#login_form_password", user: %{
            email: context.second_user_email,
            password: context.second_user_password,
            remember_me: true
          })

        logged_in_conn = submit_form(login_form, build_conn())
        member_conn = recycle(logged_in_conn)
        {:ok, view, _html} = live(member_conn, "/app/accounts/settings")
        {:ok, Map.put(context, :member_view, view)}
      end

      then_ "the read-only member does not see the delete account section", context do
        refute has_element?(context.member_view, "[data-role='delete-account']")
        :ok
      end
    end
  end
end
