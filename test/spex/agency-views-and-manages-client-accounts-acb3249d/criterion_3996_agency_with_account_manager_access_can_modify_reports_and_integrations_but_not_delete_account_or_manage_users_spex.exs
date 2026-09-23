defmodule MetricFlowSpex.AccountManagerCanModifyIntegrationsButNotDeleteOrManageUsersSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  alias MetricFlowTest.AgenciesFixtures
  alias MetricFlowTest.UsersFixtures

  spex "Agency with account manager access can modify integrations but not delete account or manage users" do
    scenario "account manager can navigate to the integrations page" do
      given_ "a user is registered and added as account_manager on a client account", context do
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
        AgenciesFixtures.account_with_member_fixture(user, :account_manager)

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

      when_ "the account manager navigates to the integrations page", context do
        {:ok, view, _html} = live(context.account_manager_conn, "/app/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the integrations page is accessible and renders the integrations heading", context do
        assert render(context.view) =~ "Integrations"
        :ok
      end

      then_ "the account manager can see platform management options", context do
        html = render(context.view)

        assert html =~ "Available Platforms" or
                 html =~ "Connect a Platform" or
                 html =~ "No platforms connected yet"

        :ok
      end
    end

    scenario "account manager does not see the Delete Account section on account settings" do
      given_ "a user has account_manager membership on a client account and is logged in", context do
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
        AgenciesFixtures.account_with_member_fixture(user, :account_manager)

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

      when_ "the account manager navigates to the account settings page", context do
        {:ok, view, _html} = live(context.account_manager_conn, "/app/accounts/settings")
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

    scenario "account manager does not see the Transfer Ownership section on account settings" do
      given_ "a user has account_manager membership on a client account and is logged in", context do
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
        AgenciesFixtures.account_with_member_fixture(user, :account_manager)

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

      when_ "the account manager navigates to the account settings page", context do
        {:ok, view, _html} = live(context.account_manager_conn, "/app/accounts/settings")
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

    scenario "account manager sees read-only account settings with no editable form" do
      given_ "a user has account_manager membership on a client account and is logged in", context do
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
        AgenciesFixtures.account_with_member_fixture(user, :account_manager)

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

      when_ "the account manager navigates to the account settings page", context do
        {:ok, view, _html} = live(context.account_manager_conn, "/app/accounts/settings")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the account name input is shown as read-only", context do
        assert has_element?(context.view, "input[readonly]")
        :ok
      end

      then_ "there is no editable settings form with a save button", context do
        refute has_element?(context.view, "#account-settings-form")
        :ok
      end
    end
  end
end
