defmodule MetricFlowSpex.Criterion827ClientSeesDefaultBrandingViaMainDomainSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Client sees default branding via the main domain", criterion: 827 do
    scenario "a client whose account was originated by an agency sees default branding on the main domain" do
      given_ :user_logged_in_as_owner

      given_ "a client whose account was originated by an agency", context do
        account = MetricFlowSpex.Fixtures.account_originated_by(context.owner_email)

        agency =
          MetricFlowTest.AgenciesFixtures.agency_with_white_label_fixture(%{
            subdomain: "branded827",
            logo_url: "https://example.com/branded827-logo.png",
            primary_color: "#654321",
            secondary_color: "#123456"
          })

        MetricFlowTest.AgenciesFixtures.grant_agency_originator_access(agency.id, account.id)

        {:ok, context}
      end

      when_ "they access the system via the main domain instead of the agency's subdomain", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "they see default branding", context do
        html = render(context.view)

        refute html =~ "branded827-logo.png"
        refute has_element?(context.view, "[data-role='agency-logo']")
        assert html =~ "MetricFlow" or has_element?(context.view, "[data-role='default-logo']")

        {:ok, context}
      end
    end
  end
end
