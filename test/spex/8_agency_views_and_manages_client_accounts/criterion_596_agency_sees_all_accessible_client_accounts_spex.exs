defmodule MetricFlowSpex.AgencySeesAllAccessibleClientAccountsSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  alias MetricFlowTest.AgenciesFixtures

  spex "Agency sees all accessible client accounts", criterion: 596 do
    scenario "agency sees all of the client accounts they have access to" do
      given_(:user_logged_in_as_owner)

      given_ "the agency has access to several client accounts", context do
        client1 = AgenciesFixtures.account_fixture(%{name: "Client 596 Alpha"})
        client2 = AgenciesFixtures.account_fixture(%{name: "Client 596 Beta"})

        MetricFlowSpex.Fixtures.grant_client_account_access(
          context.owner_email,
          client1.id,
          :admin,
          false
        )

        MetricFlowSpex.Fixtures.grant_client_account_access(
          context.owner_email,
          client2.id,
          :admin,
          false
        )

        {:ok,
         Map.merge(context, %{
           client_account_1: "Client 596 Alpha",
           client_account_2: "Client 596 Beta"
         })}
      end

      when_ "they open the client accounts list", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "all of those client accounts are shown", context do
        html = render(context.view)
        assert html =~ context.client_account_1
        assert html =~ context.client_account_2
        {:ok, context}
      end
    end
  end
end
