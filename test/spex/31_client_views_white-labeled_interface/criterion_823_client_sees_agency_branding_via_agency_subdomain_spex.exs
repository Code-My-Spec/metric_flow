defmodule MetricFlowSpex.Criterion823ClientSeesAgencyBrandingViaAgencySubdomainSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Client sees agency branding via agency subdomain", criterion: 823 do
    scenario "a client whose account was originated by an agency sees that agency's branding on its subdomain" do
      given_ :user_logged_in_as_owner

      given_ "a client whose account was originated by an agency", context do
        account = MetricFlowSpex.Fixtures.account_originated_by(context.owner_email)

        agency =
          MetricFlowTest.AgenciesFixtures.agency_with_white_label_fixture(%{
            subdomain: "branded823",
            logo_url: "https://example.com/branded823-logo.png",
            primary_color: "#123ABC",
            secondary_color: "#ABC123"
          })

        MetricFlowTest.AgenciesFixtures.grant_agency_originator_access(agency.id, account.id)

        {:ok, context}
      end

      when_ "they access the system via that agency's custom subdomain", context do
        %Plug.Conn{} = owner_conn = context.owner_conn
        conn = %{owner_conn | host: "branded823.metricflow.io"}
        {:ok, view, _html} = live(conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "they see the agency's branding", context do
        html = render(context.view)

        assert html =~ "branded823-logo.png" or html =~ "#123ABC" or
                 has_element?(context.view, "[data-role='agency-logo']")

        {:ok, context}
      end
    end
  end
end
