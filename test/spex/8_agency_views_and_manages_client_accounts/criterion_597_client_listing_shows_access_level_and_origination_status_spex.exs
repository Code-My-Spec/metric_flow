defmodule MetricFlowSpex.ClientListingShowsAccessLevelAndOriginationStatusSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  alias MetricFlowTest.AgenciesFixtures

  spex "Client listing shows access level and origination status", criterion: 597 do
    scenario "a client account listing shows the agency's access level and origination status" do
      given_(:user_logged_in_as_owner)

      given_ "a client account in the list", context do
        client = AgenciesFixtures.account_fixture(%{name: "Client 597 Corp"})

        MetricFlowSpex.Fixtures.grant_client_account_access(
          context.owner_email,
          client.id,
          :account_manager,
          true
        )

        {:ok, Map.put(context, :client_name, "Client 597 Corp")}
      end

      when_ "the agency views that listing", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "it shows the agency's access level and whether the agency originated it", context do
        html = render(context.view)
        assert html =~ context.client_name
        assert html =~ "Account Manager"
        assert html =~ "Originator"
        {:ok, context}
      end
    end
  end
end
