defmodule MetricFlowSpex.IfAgencyOriginatedTheClientAccountTheySeeOriginatorBadgeSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  alias MetricFlow.Accounts
  alias MetricFlow.Agencies
  alias MetricFlow.Users.Scope
  alias MetricFlowTest.AgenciesFixtures
  alias MetricFlowTest.UsersFixtures

  spex "If agency originated the client account, they see Originator badge" do
    scenario "agency that originated a client account sees Originator badge on the accounts page" do
      given_ :user_logged_in_as_owner

      given_ "the owner has originated a client account", context do
        owner_user = UsersFixtures.get_user_by_email(context.owner_email)
        scope = Scope.for_user(owner_user)
        [owner_account | _] = Accounts.list_accounts(scope)

        client = AgenciesFixtures.account_fixture(%{name: "Originated Client Co"})

        {:ok, _grant} = Agencies.grant_client_account_access(
          scope, owner_account.id, client.id, :admin, true
        )

        {:ok, Map.put(context, :client_name, "Originated Client Co")}
      end

      when_ "the agency owner navigates to the accounts page", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the originated client account is listed", context do
        assert render(context.view) =~ context.client_name
        :ok
      end

      then_ "an Originator badge is visible for that client account", context do
        assert render(context.view) =~ "Originator"
        :ok
      end
    end

    scenario "agency with invited (non-originator) access does NOT see Originator badge for that client" do
      given_ :user_logged_in_as_owner

      given_ "the owner has been invited to access a client account (not originated)", context do
        owner_user = UsersFixtures.get_user_by_email(context.owner_email)
        scope = Scope.for_user(owner_user)
        [owner_account | _] = Accounts.list_accounts(scope)

        client = AgenciesFixtures.account_fixture(%{name: "Invited Client Inc"})

        {:ok, _grant} = Agencies.grant_client_account_access(
          scope, owner_account.id, client.id, :admin, false
        )

        {:ok, Map.put(context, :client_name, "Invited Client Inc")}
      end

      when_ "the agency owner navigates to the accounts page", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the invited client account is listed", context do
        assert render(context.view) =~ context.client_name
        :ok
      end

      then_ "no Originator badge is shown for the invited client account", context do
        refute render(context.view) =~ "Originator"
        :ok
      end

      then_ "an Invited badge is shown instead", context do
        assert render(context.view) =~ "Invited"
        :ok
      end
    end

    scenario "agency with both originated and invited clients sees the correct badge for each" do
      given_ :user_logged_in_as_owner

      given_ "the owner has originated one client and been invited to another", context do
        owner_user = UsersFixtures.get_user_by_email(context.owner_email)
        scope = Scope.for_user(owner_user)
        [owner_account | _] = Accounts.list_accounts(scope)

        originated_client = AgenciesFixtures.account_fixture(%{name: "Founded Client LLC"})
        invited_client = AgenciesFixtures.account_fixture(%{name: "Partner Client Ltd"})

        {:ok, _grant_originated} = Agencies.grant_client_account_access(
          scope, owner_account.id, originated_client.id, :admin, true
        )

        {:ok, _grant_invited} = Agencies.grant_client_account_access(
          scope, owner_account.id, invited_client.id, :read_only, false
        )

        {:ok, Map.merge(context, %{
          originated_client_name: "Founded Client LLC",
          invited_client_name: "Partner Client Ltd"
        })}
      end

      when_ "the agency owner navigates to the accounts page", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "both client accounts are listed on the page", context do
        html = render(context.view)
        assert html =~ context.originated_client_name
        assert html =~ context.invited_client_name
        :ok
      end

      then_ "the Originator badge appears for the originated client", context do
        assert render(context.view) =~ "Originator"
        :ok
      end

      then_ "the Invited badge appears for the invited client", context do
        assert render(context.view) =~ "Invited"
        :ok
      end
    end
  end
end
