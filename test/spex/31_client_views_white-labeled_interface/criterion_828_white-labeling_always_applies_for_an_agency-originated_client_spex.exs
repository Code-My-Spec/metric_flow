defmodule MetricFlowSpex.Criterion828WhiteLabelingAlwaysAppliesForAgencyOriginatedClientSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "White-labeling always applies for an agency-originated client", criterion: 828 do
    scenario "an agency-originated client always sees white-labeling through the agency subdomain, regardless of other settings" do
      given_ :user_logged_in_as_owner

      given_ "a client whose account was originated by an agency", context do
        account = MetricFlowSpex.Fixtures.account_originated_by(context.owner_email)

        agency =
          MetricFlowTest.AgenciesFixtures.agency_with_white_label_fixture(%{
            subdomain: "branded828",
            logo_url: "https://example.com/branded828-logo.png",
            primary_color: "#998877",
            secondary_color: "#778899"
          })

        MetricFlowTest.AgenciesFixtures.grant_agency_originator_access(agency.id, account.id)

        {:ok, context}
      end

      when_ "they access the system through the agency's subdomain", context do
        %Plug.Conn{} = owner_conn = context.owner_conn
        conn = %{owner_conn | host: "branded828.metricflow.io"}
        {:ok, view, _html} = live(conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "white-labeling is always applied for that client, regardless of other settings", context do
        assert has_element?(context.view, "[data-role='agency-logo']") or
                 render(context.view) =~ "branded828-logo.png",
               "Expected white-labeling to always be applied for an agency-originated client"

        {:ok, context}
      end
    end
  end
end
