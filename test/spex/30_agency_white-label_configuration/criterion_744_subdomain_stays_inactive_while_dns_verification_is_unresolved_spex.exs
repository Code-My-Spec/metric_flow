defmodule MetricFlowSpex.SubdomainStaysInactiveWhileDnsVerificationIsUnresolvedSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  alias MetricFlowTest.AgenciesFixtures

  spex "Subdomain stays inactive while DNS verification is unresolved", criterion: 744 do
    scenario "a client accessing an unverified white-label subdomain does not see the agency's branding" do
      given_(:user_logged_in_as_owner)

      given_ "a custom subdomain has been configured but DNS verification has not succeeded",
             context do
        account = MetricFlowSpex.Fixtures.account_originated_by(context.owner_email)

        agency =
          AgenciesFixtures.agency_with_white_label_fixture(%{
            subdomain: "unverified744",
            logo_url: "https://cdn.clientbrand.com/logo.png",
            primary_color: "#1A2B3C",
            secondary_color: "#3C2B1A"
          })

        AgenciesFixtures.grant_agency_originator_access(agency.id, account.id)

        {:ok, Map.merge(context, %{agency: agency, account: account})}
      end

      when_ "clients access reports via that subdomain", context do
        %Plug.Conn{} = owner_conn = context.owner_conn
        conn = %{owner_conn | host: "unverified744.metricflow.io"}
        {:ok, view, _html} = live(conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the subdomain remains inactive and the default domain continues to serve reports",
            context do
        html = render(context.view)

        refute has_element?(context.view, "[data-white-label='true']"),
               "Expected an unverified subdomain to NOT activate white-labeled branding, got: #{html}"

        refute html =~ "cdn.clientbrand.com/logo.png"
        {:ok, context}
      end
    end
  end
end
