defmodule MetricFlowSpex.AgencyWithAdminAccessCanDoEverythingExceptDeleteTheAccountSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  alias MetricFlowTest.AgenciesFixtures
  alias MetricFlowTest.UsersFixtures

  spex "Agency with admin access can do everything except delete the account" do
    scenario "admin user sees the editable account settings form with a Save Changes button" do
      given_ "a user is registered and has admin membership on a client account", context do
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
        AgenciesFixtures.account_with_member_fixture(user, :admin)

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

      when_ "the admin user navigates to the account settings page", context do
        {:ok, view, _html} = live(context.admin_conn, "/app/accounts/settings")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the editable account settings form is rendered", context do
        assert has_element?(context.view, "#account-settings-form")
        :ok
      end

      then_ "the Save Changes button is visible", context do
        assert render(context.view) =~ "Save Changes"
        :ok
      end
    end

    scenario "admin user can access the integrations page" do
      given_ "a user is registered and has admin membership on a client account", context do
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
        AgenciesFixtures.account_with_member_fixture(user, :admin)

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

      when_ "the admin user navigates to the integrations page", context do
        {:ok, view, _html} = live(context.admin_conn, "/app/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the integrations page is accessible and renders content", context do
        assert render(context.view) =~ "Integrations"
        :ok
      end
    end

    scenario "admin user can access the account members page" do
      given_ "a user is registered and has admin membership on a client account", context do
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
        AgenciesFixtures.account_with_member_fixture(user, :admin)

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
        {:ok, view, _html} = live(context.admin_conn, "/app/accounts/members")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the members page is accessible and renders member content", context do
        assert render(context.view) =~ "Members"
        :ok
      end
    end

    scenario "admin user does NOT see the Delete Account section" do
      given_ "a user is registered and has admin membership on a client account", context do
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
        AgenciesFixtures.account_with_member_fixture(user, :admin)

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

      when_ "the admin user navigates to the account settings page", context do
        {:ok, view, _html} = live(context.admin_conn, "/app/accounts/settings")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the Delete Account section is not visible", context do
        refute has_element?(context.view, "[data-role='delete-account']")
        :ok
      end

      then_ "the delete account form is not rendered in the page", context do
        refute render(context.view) =~ "Delete Account"
        :ok
      end
    end

    scenario "admin user does NOT see the Transfer Ownership section" do
      given_ "a user is registered and has admin membership on a client account", context do
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
        AgenciesFixtures.account_with_member_fixture(user, :admin)

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

      when_ "the admin user navigates to the account settings page", context do
        {:ok, view, _html} = live(context.admin_conn, "/app/accounts/settings")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the Transfer Ownership section is not visible", context do
        refute has_element?(context.view, "[data-role='transfer-ownership']")
        :ok
      end

      then_ "no transfer ownership controls are rendered in the page", context do
        refute render(context.view) =~ "Transfer Ownership"
        :ok
      end
    end
  end
end
