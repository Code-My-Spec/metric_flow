defmodule MetricFlowSpex.AgencyCannotSeeOtherUsersUnlessAdminSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  alias MetricFlowTest.AgenciesFixtures
  alias MetricFlowTest.UsersFixtures

  spex "Agency cannot see other users who have access to the client account unless they have admin access" do
    scenario "read-only agency user cannot see the members list on the members page" do
      given_ "a user is registered and added as read_only member on a client account", context do
        email = "readonly#{System.unique_integer([:positive])}@example.com"
        password = "SecurePassword123!"

        reg_conn = build_conn()
        {:ok, reg_view, _html} = live(reg_conn, "/users/register")

        reg_view
        |> form("#registration_form", user: %{
          email: email,
          password: password,
          account_name: "My Personal Account"
        })
        |> render_submit()

        user = UsersFixtures.get_user_by_email(email)
        _client_account = AgenciesFixtures.account_with_member_fixture(user, :read_only)

        login_conn = build_conn()
        {:ok, login_view, _html} = live(login_conn, "/users/log-in")

        login_form =
          form(login_view, "#login_form_password", user: %{
            email: email,
            password: password,
            remember_me: true
          })

        logged_in_conn = submit_form(login_form, login_conn)
        authed_conn = recycle(logged_in_conn)

        {:ok, Map.put(context, :readonly_conn, authed_conn)}
      end

      when_ "the read-only user navigates to the account members page", context do
        {:ok, view, _html} = live(context.readonly_conn, "/accounts/members")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the members list section is not visible to the read-only user", context do
        refute has_element?(context.view, "[data-role='members-list']")
        :ok
      end

      then_ "there is no member email or row rendered in the page", context do
        refute has_element?(context.view, "[data-role='member-row']")
        :ok
      end
    end

    scenario "admin agency user CAN see the members list on the members page" do
      given_ "a user is registered and added as admin member on a client account", context do
        email = "admin#{System.unique_integer([:positive])}@example.com"
        password = "SecurePassword123!"

        reg_conn = build_conn()
        {:ok, reg_view, _html} = live(reg_conn, "/users/register")

        reg_view
        |> form("#registration_form", user: %{
          email: email,
          password: password,
          account_name: "My Personal Account"
        })
        |> render_submit()

        user = UsersFixtures.get_user_by_email(email)
        _client_account = AgenciesFixtures.account_with_member_fixture(user, :admin)

        login_conn = build_conn()
        {:ok, login_view, _html} = live(login_conn, "/users/log-in")

        login_form =
          form(login_view, "#login_form_password", user: %{
            email: email,
            password: password,
            remember_me: true
          })

        logged_in_conn = submit_form(login_form, login_conn)
        authed_conn = recycle(logged_in_conn)

        {:ok, Map.put(context, :admin_conn, authed_conn)}
      end

      when_ "the admin user navigates to the account members page", context do
        {:ok, view, _html} = live(context.admin_conn, "/accounts/members")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the members list section is visible to the admin user", context do
        assert has_element?(context.view, "[data-role='members-list']")
        :ok
      end

      then_ "member information is rendered in the page", context do
        assert has_element?(context.view, "[data-role='member-row']")
        :ok
      end
    end

    scenario "account manager agency user cannot see the members list on the members page" do
      given_ "a user is registered and added as account_manager member on a client account", context do
        email = "acctmgr#{System.unique_integer([:positive])}@example.com"
        password = "SecurePassword123!"

        reg_conn = build_conn()
        {:ok, reg_view, _html} = live(reg_conn, "/users/register")

        reg_view
        |> form("#registration_form", user: %{
          email: email,
          password: password,
          account_name: "My Personal Account"
        })
        |> render_submit()

        user = UsersFixtures.get_user_by_email(email)
        _client_account = AgenciesFixtures.account_with_member_fixture(user, :account_manager)

        login_conn = build_conn()
        {:ok, login_view, _html} = live(login_conn, "/users/log-in")

        login_form =
          form(login_view, "#login_form_password", user: %{
            email: email,
            password: password,
            remember_me: true
          })

        logged_in_conn = submit_form(login_form, login_conn)
        authed_conn = recycle(logged_in_conn)

        {:ok, Map.put(context, :account_manager_conn, authed_conn)}
      end

      when_ "the account manager navigates to the account members page", context do
        {:ok, view, _html} = live(context.account_manager_conn, "/accounts/members")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the members list section is not visible to the account manager", context do
        refute has_element?(context.view, "[data-role='members-list']")
        :ok
      end

      then_ "no member rows are rendered in the page for the account manager", context do
        refute has_element?(context.view, "[data-role='member-row']")
        :ok
      end
    end
  end
end
