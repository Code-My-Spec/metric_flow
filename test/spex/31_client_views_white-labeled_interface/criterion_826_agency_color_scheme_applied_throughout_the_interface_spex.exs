defmodule MetricFlowSpex.Criterion826AgencyColorSchemeAppliedThroughoutInterfaceSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Agency color scheme applied throughout the interface", criterion: 826 do
    scenario "the agency's color scheme is applied consistently as the client navigates through the application" do
      given_ :user_logged_in_as_owner

      given_ "a client viewing a white-labeled interface", context do
        account = MetricFlowSpex.Fixtures.account_originated_by(context.owner_email)

        agency =
          MetricFlowTest.AgenciesFixtures.agency_with_white_label_fixture(%{
            subdomain: "branded826",
            logo_url: "https://example.com/branded826-logo.png",
            primary_color: "#7788AA",
            secondary_color: "#AA7788"
          })

        MetricFlowTest.AgenciesFixtures.grant_agency_originator_access(agency.id, account.id)

        {:ok, Map.put(context, :agency_conn, %{context.owner_conn | host: "branded826.metricflow.io"})}
      end

      when_ "they navigate through the application", context do
        {:ok, dashboard_view, dashboard_html} = live(context.agency_conn, "/app/dashboard")
        {:ok, reports_view, reports_html} = live(context.agency_conn, "/app/reports")

        {:ok,
         Map.merge(context, %{
           dashboard_view: dashboard_view,
           dashboard_html: dashboard_html,
           reports_view: reports_view,
           reports_html: reports_html
         })}
      end

      then_ "the agency's color scheme is applied consistently throughout", context do
        assert context.dashboard_html =~ "#7788AA" or
                 has_element?(context.dashboard_view, "[data-white-label]")

        assert context.reports_html =~ "#7788AA" or
                 has_element?(context.reports_view, "[data-white-label]")

        {:ok, context}
      end
    end
  end
end
