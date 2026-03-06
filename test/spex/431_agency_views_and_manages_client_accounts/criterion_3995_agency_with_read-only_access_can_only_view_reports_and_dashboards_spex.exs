defmodule MetricFlowSpex.AgencyWithReadOnlyAccessCanOnlyViewReportsAndDashboardsSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  alias MetricFlowTest.AgenciesFixtures
  alias MetricFlowTest.UsersFixtures

  spex "Agency with read-only access can only view reports and dashboards" do
    scenario "read-only user sees the client account listed on the accounts page" do
      given_ "a user is registered and a client account exists where they have read-only membership", context do
        email = "readonly#{System.unique_integer([:positive])}@example.com"
        password = "SecurePassword123!"

        # Register through UI — this creates their personal account
        reg_conn = build_conn()
        {:ok, reg_view, _html} = live(reg_conn, "/users/register")

        reg_view
        |> form("#registration_form", user: %{
          email: email,
          password: password,
          account_name: "My Personal Account"
        })
        |> render_submit()

        # Retrieve the user and add them as a read_only member of a client account via fixture
        user = UsersFixtures.get_user_by_email(email)
        client_account = AgenciesFixtures.account_with_member_fixture(user, :read_only)

        # Log in through UI
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

        {:ok, Map.merge(context, %{
          readonly_conn: authed_conn,
          client_account_name: client_account.name
        })}
      end

      when_ "the read-only user navigates to the accounts page", context do
        {:ok, view, _html} = live(context.readonly_conn, "/accounts")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the client account is listed on the accounts page", context do
        assert render(context.view) =~ context.client_account_name
        :ok
      end
    end

    scenario "read-only user sees read-only account settings with no edit form" do
      given_ "a user has read-only membership on a client account and is logged in", context do
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
        AgenciesFixtures.account_with_member_fixture(user, :read_only)

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

      when_ "the read-only user navigates to the account settings page", context do
        {:ok, view, _html} = live(context.readonly_conn, "/accounts/settings")
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

    scenario "read-only user does not see the Delete Account section" do
      given_ "a user has read-only membership on a client account and is logged in", context do
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
        AgenciesFixtures.account_with_member_fixture(user, :read_only)

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

      when_ "the read-only user navigates to the account settings page", context do
        {:ok, view, _html} = live(context.readonly_conn, "/accounts/settings")
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

    scenario "read-only user does not see the Transfer Ownership section" do
      given_ "a user has read-only membership on a client account and is logged in", context do
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
        AgenciesFixtures.account_with_member_fixture(user, :read_only)

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

      when_ "the read-only user navigates to the account settings page", context do
        {:ok, view, _html} = live(context.readonly_conn, "/accounts/settings")
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
