defmodule MetricFlowSpex.Criterion825AgencyLogoAppearsInNavigationHeaderSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Agency logo appears in the navigation header", criterion: 825 do
    scenario "a client viewing a white-labeled interface sees the agency's logo in the navigation header" do
      given_ :user_logged_in_as_owner

      given_ "a client viewing a white-labeled interface", context do
        account = MetricFlowSpex.Fixtures.account_originated_by(context.owner_email)

        agency =
          MetricFlowTest.AgenciesFixtures.agency_with_white_label_fixture(%{
            subdomain: "branded825",
            logo_url: "https://example.com/branded825-logo.png",
            primary_color: "#010203",
            secondary_color: "#040506"
          })

        MetricFlowTest.AgenciesFixtures.grant_agency_originator_access(agency.id, account.id)

        %Plug.Conn{} = owner_conn = context.owner_conn
        conn = %{owner_conn | host: "branded825.metricflow.io"}
        {:ok, view, _html} = live(conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "they look at the navigation header", context do
        {:ok, context}
      end

      then_ "the agency's logo is displayed there", context do
        assert has_element?(context.view, "[data-role='agency-logo']"),
               "Expected the agency's logo to be displayed in the navigation header"

        {:ok, context}
      end
    end
  end
end
