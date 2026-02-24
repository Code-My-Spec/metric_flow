defmodule MetricFlowSpex.AllUsersOnAccountSeeTheSameDataWithIsolationSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "All users on an account see the same data with account-level isolation" do
    scenario "two members of the same account see the same members list" do
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

      when_ "the owner views the members page", context do
        {:ok, view, html} = live(context.owner_conn, "/accounts/members")
        {:ok, Map.put(context, :owner_members_html, html)}
      end

      then_ "the owner sees both members", context do
        assert context.owner_members_html =~ context.owner_email
        assert context.owner_members_html =~ context.second_user_email
        :ok
      end

      when_ "the second user logs in and views the same members page", context do
        {:ok, login_view, _html} = live(build_conn(), "/users/log-in")

        login_form =
          form(login_view, "#login_form_password", user: %{
            email: context.second_user_email,
            password: context.second_user_password,
            remember_me: true
          })

        logged_in_conn = submit_form(login_form, build_conn())
        member_conn = recycle(logged_in_conn)
        {:ok, _view, html} = live(member_conn, "/accounts/members")
        {:ok, Map.put(context, :member_members_html, html)}
      end

      then_ "the second user sees the same members", context do
        assert context.member_members_html =~ context.owner_email
        assert context.member_members_html =~ context.second_user_email
        :ok
      end
    end

    scenario "users from different accounts cannot see each other's members" do
      given_ :user_logged_in_as_owner

      given_ "a completely separate user registers their own account", context do
        email = "separate#{System.unique_integer([:positive])}@example.com"
        password = "SecurePassword123!"

        {:ok, reg_view, _html} = live(build_conn(), "/users/register")

        reg_view
        |> form("#registration_form", user: %{
          email: email,
          password: password,
          account_name: "Separate Account"
        })
        |> render_submit()

        {:ok, login_view, _html} = live(build_conn(), "/users/log-in")

        login_form =
          form(login_view, "#login_form_password", user: %{
            email: email,
            password: password,
            remember_me: true
          })

        logged_in_conn = submit_form(login_form, build_conn())
        {:ok, Map.merge(context, %{separate_conn: recycle(logged_in_conn), separate_email: email})}
      end

      when_ "the separate user views their members page", context do
        {:ok, _view, html} = live(context.separate_conn, "/accounts/members")
        {:ok, Map.put(context, :separate_members_html, html)}
      end

      then_ "they do not see the owner from the first account", context do
        refute context.separate_members_html =~ context.owner_email
        :ok
      end

      then_ "they only see their own email", context do
        assert context.separate_members_html =~ context.separate_email
        :ok
      end
    end
  end
end
