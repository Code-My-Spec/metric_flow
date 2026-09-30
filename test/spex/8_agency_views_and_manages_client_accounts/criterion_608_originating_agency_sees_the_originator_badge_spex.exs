defmodule MetricFlowSpex.OriginatingAgencySeesTheOriginatorBadgeSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  alias MetricFlowTest.AgenciesFixtures

  spex "Originating agency sees the Originator badge", criterion: 608 do
    scenario "an agency that originated a client account sees the Originator badge on its listing" do
      given_(:user_logged_in_as_owner)

      given_ "the agency originated a client account", context do
        client = AgenciesFixtures.account_fixture(%{name: "Client 608 Originated"})

        MetricFlowSpex.Fixtures.grant_client_account_access(
          context.owner_email,
          client.id,
          :admin,
          true
        )

        {:ok, Map.put(context, :client_name, "Client 608 Originated")}
      end

      when_ "they view that client account's listing", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "they see an Originator badge on it", context do
        html = render(context.view)
        assert html =~ context.client_name
        assert html =~ "Originator"
        {:ok, context}
      end
    end
  end
end
