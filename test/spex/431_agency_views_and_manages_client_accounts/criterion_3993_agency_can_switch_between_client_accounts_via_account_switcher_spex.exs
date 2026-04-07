defmodule MetricFlowSpex.AgencyCanSwitchBetweenClientAccountsViaAccountSwitcherSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  alias MetricFlow.Accounts
  alias MetricFlow.Agencies
  alias MetricFlow.Users.Scope
  alias MetricFlowTest.AgenciesFixtures
  alias MetricFlowTest.UsersFixtures

  spex "Agency can switch between client accounts via account switcher" do
    scenario "agency owner sees a switch action on each client account card on the accounts page" do
      given_ :user_logged_in_as_owner

      given_ "the owner has been granted access to a client account", context do
        owner_user = UsersFixtures.get_user_by_email(context.owner_email)
        scope = Scope.for_user(owner_user)
        [owner_account | _] = Accounts.list_accounts(scope)

        client = AgenciesFixtures.account_fixture(%{name: "Client Alpha"})

        {:ok, _grant} = Agencies.grant_client_account_access(
          scope, owner_account.id, client.id, :admin, false
        )

        {:ok, Map.put(context, :client_account_name, "Client Alpha")}
      end

      when_ "the agency owner navigates to the accounts page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the client account card shows a switch account action", context do
        assert has_element?(context.view, "[data-role='switch-account']")
        :ok
      end

      then_ "the switch account action is labeled with the client account name", context do
        assert has_element?(context.view, "[data-role='switch-account']", context.client_account_name)
        :ok
      end
    end

    scenario "agency owner can click a client account card to switch into that client's context" do
      given_ :user_logged_in_as_owner

      given_ "the owner has been granted access to a client account named Client Beta", context do
        owner_user = UsersFixtures.get_user_by_email(context.owner_email)
        scope = Scope.for_user(owner_user)
        [owner_account | _] = Accounts.list_accounts(scope)

        client = AgenciesFixtures.account_fixture(%{name: "Client Beta"})

        {:ok, _grant} = Agencies.grant_client_account_access(
          scope, owner_account.id, client.id, :admin, false
        )

        {:ok, Map.put(context, :client_account_name, "Client Beta")}
      end

      when_ "the agency owner navigates to the accounts page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the agency owner clicks the switch action for the client account", context do
        element(context.view, "[data-role='switch-account']", context.client_account_name)
        |> render_click()

        {:ok, Map.put(context, :view, context.view)}
      end

      then_ "the UI reflects the selected client account as the active context", context do
        html = render(context.view)
        assert html =~ context.client_account_name
        :ok
      end
    end

    scenario "agency owner switching to a client account sees the client account name in the settings page" do
      given_ :user_logged_in_as_owner

      given_ "the owner has been granted access to a client account named Switched Client", context do
        owner_user = UsersFixtures.get_user_by_email(context.owner_email)
        scope = Scope.for_user(owner_user)
        [owner_account | _] = Accounts.list_accounts(scope)

        client = AgenciesFixtures.account_fixture(%{name: "Switched Client"})

        {:ok, _grant} = Agencies.grant_client_account_access(
          scope, owner_account.id, client.id, :admin, false
        )

        {:ok, Map.put(context, :client_account_name, "Switched Client")}
      end

      when_ "the agency owner navigates to the accounts page and switches to the client account", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts")

        element(view, "[data-role='switch-account']", context.client_account_name)
        |> render_click()

        {:ok, Map.put(context, :accounts_view, view)}
      end

      when_ "the agency owner navigates to account settings", context do
        {:ok, settings_view, _html} = live(context.owner_conn, "/app/accounts/settings")
        {:ok, Map.put(context, :settings_view, settings_view)}
      end

      then_ "the settings page displays the client account as the active account", context do
        assert render(context.settings_view) =~ context.client_account_name
        :ok
      end
    end

    scenario "agency owner with multiple clients can switch between them independently" do
      given_ :user_logged_in_as_owner

      given_ "the owner has been granted access to two different client accounts", context do
        owner_user = UsersFixtures.get_user_by_email(context.owner_email)
        scope = Scope.for_user(owner_user)
        [owner_account | _] = Accounts.list_accounts(scope)

        client_one = AgenciesFixtures.account_fixture(%{name: "First Client Co"})
        client_two = AgenciesFixtures.account_fixture(%{name: "Second Client Inc"})

        {:ok, _grant1} = Agencies.grant_client_account_access(
          scope, owner_account.id, client_one.id, :admin, false
        )

        {:ok, _grant2} = Agencies.grant_client_account_access(
          scope, owner_account.id, client_two.id, :admin, false
        )

        {:ok, Map.merge(context, %{
          client_one_name: "First Client Co",
          client_two_name: "Second Client Inc"
        })}
      end

      when_ "the agency owner navigates to the accounts page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "both client accounts show a switch account action", context do
        html = render(context.view)
        assert html =~ context.client_one_name
        assert html =~ context.client_two_name
        :ok
      end

      then_ "the switch action is available for the first client account", context do
        assert has_element?(context.view, "[data-role='switch-account']", context.client_one_name)
        :ok
      end

      then_ "the switch action is available for the second client account", context do
        assert has_element?(context.view, "[data-role='switch-account']", context.client_two_name)
        :ok
      end
    end
  end
end
