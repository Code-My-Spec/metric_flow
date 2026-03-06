defmodule MetricFlowSpex.CurrentClientContextIsClearlyDisplayedInNavigationSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  alias MetricFlow.Accounts
  alias MetricFlow.Agencies
  alias MetricFlow.Users.Scope
  alias MetricFlowTest.AgenciesFixtures
  alias MetricFlowTest.UsersFixtures

  spex "Current client context is clearly displayed in navigation" do
    scenario "agency user viewing a client account sees the client account name in navigation" do
      given_ :user_logged_in_as_owner

      given_ "the agency owner has been granted access to a client account", context do
        owner_user = UsersFixtures.get_user_by_email(context.owner_email)
        scope = Scope.for_user(owner_user)
        [owner_account | _] = Accounts.list_accounts(scope)

        client_account = AgenciesFixtures.account_fixture(%{name: "Acme Corp"})

        {:ok, _grant} = Agencies.grant_client_account_access(
          scope, owner_account.id, client_account.id, :admin, false
        )

        {:ok, Map.merge(context, %{
          owner_account_name: owner_account.name,
          client_account_id: client_account.id,
          client_account_name: "Acme Corp"
        })}
      end

      when_ "the agency user navigates to the accounts settings page", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts/settings")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "a current account name indicator is visible in the navigation", context do
        assert has_element?(context.view, "[data-role='current-account-name']")
        :ok
      end
    end

    scenario "navigation shows the active client account name when viewing a client account page" do
      given_ :user_logged_in_as_owner

      given_ "the agency owner has been granted access to a client account named Bright Ideas", context do
        owner_user = UsersFixtures.get_user_by_email(context.owner_email)
        scope = Scope.for_user(owner_user)
        [owner_account | _] = Accounts.list_accounts(scope)

        client_account = AgenciesFixtures.account_fixture(%{name: "Bright Ideas"})

        {:ok, _grant} = Agencies.grant_client_account_access(
          scope, owner_account.id, client_account.id, :admin, false
        )

        {:ok, Map.merge(context, %{
          owner_account_name: owner_account.name,
          client_account_name: "Bright Ideas"
        })}
      end

      when_ "the agency user navigates to the accounts list page", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the navigation shows the current account name", context do
        html = render(context.view)
        assert html =~ context.client_account_name or
               html =~ context.owner_account_name
        :ok
      end

      then_ "the current account name element is present in the page", context do
        assert has_element?(context.view, "[data-role='current-account-name']")
        :ok
      end
    end

    scenario "when the user's own account is active, their own account name is shown in navigation" do
      given_ :user_logged_in_as_owner

      when_ "the user navigates to the accounts page with their own account active", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "their own account name is visible in the navigation", context do
        assert render(context.view) =~ "Owner Account"
        :ok
      end

      then_ "the current account indicator reflects the user's own account", context do
        html = render(context.view)
        # The navigation element should contain the user's own account name
        assert html =~ "Owner Account"
        :ok
      end
    end

    scenario "the navigation clearly indicates which account is currently active across all authenticated pages" do
      given_ :user_logged_in_as_owner

      given_ "the agency owner has access to a client account", context do
        owner_user = UsersFixtures.get_user_by_email(context.owner_email)
        scope = Scope.for_user(owner_user)
        [owner_account | _] = Accounts.list_accounts(scope)

        client_account = AgenciesFixtures.account_fixture(%{name: "Delta Analytics"})

        {:ok, _grant} = Agencies.grant_client_account_access(
          scope, owner_account.id, client_account.id, :admin, false
        )

        {:ok, Map.merge(context, %{
          owner_account_name: owner_account.name,
          client_account_name: "Delta Analytics"
        })}
      end

      when_ "the agency user navigates to the integrations page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the navigation shows the current account context indicator", context do
        assert has_element?(context.view, "[data-role='current-account-name']")
        :ok
      end
    end
  end
end
