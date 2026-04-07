defmodule MetricFlowSpex.AgencySeesListOfAllClientAccountsTheyHaveAccessToSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  alias MetricFlow.Accounts
  alias MetricFlow.Agencies
  alias MetricFlow.Users.Scope
  alias MetricFlowTest.AgenciesFixtures
  alias MetricFlowTest.UsersFixtures

  spex "Agency sees list of all client accounts they have access to" do
    scenario "agency owner with multiple client accounts sees all of them listed on the accounts page" do
      given_ :user_logged_in_as_owner

      given_ "the owner has been granted access to multiple client accounts", context do
        # Get the owner user and their scope via domain layer (no UI exists for client account management)
        owner_user = UsersFixtures.get_user_by_email(context.owner_email)
        scope = Scope.for_user(owner_user)
        [owner_account | _] = Accounts.list_accounts(scope)

        # Create client accounts via fixture (no UI for creating client accounts exists yet)
        client1 = AgenciesFixtures.account_fixture(%{name: "Client Alpha"})
        client2 = AgenciesFixtures.account_fixture(%{name: "Client Beta"})

        # Grant the agency owner access to the client accounts
        {:ok, _grant1} = Agencies.grant_client_account_access(
          scope, owner_account.id, client1.id, :admin, true
        )
        {:ok, _grant2} = Agencies.grant_client_account_access(
          scope, owner_account.id, client2.id, :admin, true
        )

        {:ok, Map.merge(context, %{
          client_account_1: "Client Alpha",
          client_account_2: "Client Beta"
        })}
      end

      when_ "the agency owner navigates to the accounts page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the first client account name is visible in the accounts list", context do
        assert render(context.view) =~ context.client_account_1
        :ok
      end

      then_ "the second client account name is visible in the accounts list", context do
        assert render(context.view) =~ context.client_account_2
        :ok
      end
    end

    scenario "agency user with no client accounts sees only their own account on the accounts page" do
      given_ :user_logged_in_as_owner

      when_ "the agency user navigates to the accounts page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "only their own account name is shown", context do
        assert render(context.view) =~ "Owner Account"
        :ok
      end

      then_ "no client accounts appear in the list", context do
        html = render(context.view)
        refute html =~ "Client Alpha"
        refute html =~ "Client Beta"
        :ok
      end
    end
  end
end
