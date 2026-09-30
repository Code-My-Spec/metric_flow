defmodule MetricFlowSpex.WhiteLabeledInstanceShowsNoAndersonAnalyticsBrandingSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  alias MetricFlowTest.AgenciesFixtures

  spex "White-labeled instance shows no Anderson Analytics branding", criterion: 745 do
    scenario "a client viewing reports through the white-labeled instance sees no Anderson Analytics branding" do
      given_(:user_logged_in_as_owner)

      given_ "an agency has completed white-label configuration", context do
        account = MetricFlowSpex.Fixtures.account_originated_by(context.owner_email)

        agency =
          AgenciesFixtures.agency_with_white_label_fixture(%{
            subdomain: "nobrand745",
            logo_url: "https://cdn.clientbrand.com/logo.png",
            primary_color: "#1A2B3C",
            secondary_color: "#3C2B1A"
          })

        AgenciesFixtures.grant_agency_originator_access(agency.id, account.id)

        {:ok, Map.merge(context, %{agency: agency, account: account})}
      end

      when_ "a client views reports through the white-labeled instance", context do
        %Plug.Conn{} = owner_conn = context.owner_conn
        conn = %{owner_conn | host: "nobrand745.metricflow.io"}
        {:ok, view, _html} = live(conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "no Anderson Analytics branding is visible anywhere", context do
        html = render(context.view)

        refute html =~ "Anderson Analytics",
               "Expected no 'Anderson Analytics' branding on the white-labeled instance, got: #{html}"

        assert html =~ "cdn.clientbrand.com/logo.png" or
                 has_element?(context.view, "[data-role='agency-logo']"),
               "Expected the agency's own branding to be shown instead"

        {:ok, context}
      end
    end
  end
end
