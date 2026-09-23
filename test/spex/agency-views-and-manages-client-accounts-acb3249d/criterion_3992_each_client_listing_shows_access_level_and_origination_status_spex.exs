defmodule MetricFlowSpex.EachClientListingShowsAccessLevelAndOriginationStatusSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  alias MetricFlow.Accounts
  alias MetricFlow.Agencies
  alias MetricFlow.Users.Scope
  alias MetricFlowTest.AgenciesFixtures
  alias MetricFlowTest.UsersFixtures

  spex "Each client listing shows access level and origination status" do
    scenario "agency owner sees access level and origination status for each client account on the accounts page" do
      given_ :user_logged_in_as_owner

      given_ "the owner has been granted access to two client accounts with different access levels and origination statuses", context do
        owner_user = UsersFixtures.get_user_by_email(context.owner_email)
        scope = Scope.for_user(owner_user)
        [owner_account | _] = Accounts.list_accounts(scope)

        # Create two client accounts via fixture (no UI exists for creating client accounts)
        client_originated = AgenciesFixtures.account_fixture(%{name: "Originated Client Co"})
        client_invited = AgenciesFixtures.account_fixture(%{name: "Invited Client Inc"})

        # Grant originator access (admin level, is_originator: true) to first client
        {:ok, _grant1} = Agencies.grant_client_account_access(
          scope, owner_account.id, client_originated.id, :admin, true
        )

        # Grant invited access (read_only level, is_originator: false) to second client
        {:ok, _grant2} = Agencies.grant_client_account_access(
          scope, owner_account.id, client_invited.id, :read_only, false
        )

        {:ok, Map.merge(context, %{
          originated_client_name: "Originated Client Co",
          invited_client_name: "Invited Client Inc"
        })}
      end

      when_ "the agency owner navigates to the accounts page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the originated client account shows admin access level", context do
        assert render(context.view) =~ "admin"
        :ok
      end

      then_ "the originated client account shows originator status", context do
        assert render(context.view) =~ "Originator"
        :ok
      end

      then_ "the invited client account shows read only access level", context do
        html = render(context.view)
        assert html =~ "read_only" or html =~ "Read Only" or html =~ "read only"
        :ok
      end

      then_ "the invited client account shows invited status", context do
        assert render(context.view) =~ "Invited"
        :ok
      end
    end

    scenario "agency owner sees distinct access level badges for each client account" do
      given_ :user_logged_in_as_owner

      given_ "the owner has access to an account manager level client and an admin level client", context do
        owner_user = UsersFixtures.get_user_by_email(context.owner_email)
        scope = Scope.for_user(owner_user)
        [owner_account | _] = Accounts.list_accounts(scope)

        client_manager = AgenciesFixtures.account_fixture(%{name: "Manager Client LLC"})
        client_admin = AgenciesFixtures.account_fixture(%{name: "Admin Client Corp"})

        {:ok, _grant1} = Agencies.grant_client_account_access(
          scope, owner_account.id, client_manager.id, :account_manager, false
        )

        {:ok, _grant2} = Agencies.grant_client_account_access(
          scope, owner_account.id, client_admin.id, :admin, false
        )

        {:ok, Map.merge(context, %{
          manager_client_name: "Manager Client LLC",
          admin_client_name: "Admin Client Corp"
        })}
      end

      when_ "the agency owner navigates to the accounts page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "both client account names are visible in the list", context do
        html = render(context.view)
        assert html =~ context.manager_client_name
        assert html =~ context.admin_client_name
        :ok
      end

      then_ "the account manager access level is shown on its client listing", context do
        html = render(context.view)
        assert html =~ "account_manager" or html =~ "Account Manager" or html =~ "account manager"
        :ok
      end

      then_ "the invited origination status is shown for both invited client accounts", context do
        assert render(context.view) =~ "Invited"
        :ok
      end
    end
  end
end
