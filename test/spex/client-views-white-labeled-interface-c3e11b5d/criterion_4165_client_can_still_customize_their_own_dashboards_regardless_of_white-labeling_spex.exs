defmodule MetricFlowSpex.ClientCanCustomizeDashboardsRegardlessOfWhiteLabelingSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Client can still customize their own dashboards regardless of white-labeling" do
    scenario "client can use dashboard filters even with agency white-labeling active" do
      given_ :owner_with_integrations

      given_ "the client's account is originated by an agency with white-label branding", context do
        user = MetricFlowTest.UsersFixtures.get_user_by_email(context.owner_email)
        account = MetricFlow.Repo.get_by!(MetricFlow.Accounts.Account, originator_user_id: user.id)

        agency = MetricFlowTest.AgenciesFixtures.agency_with_white_label_fixture(%{
          subdomain: "customizable",
          logo_url: "https://example.com/agency-logo.png",
          primary_color: "#CC0000",
          secondary_color: "#0000CC"
        })

        MetricFlowTest.AgenciesFixtures.grant_agency_originator_access(agency.id, account.id)

        {:ok, Map.merge(context, %{agency: agency})}
      end

      given_ "the client navigates to the dashboard via the agency subdomain", context do
        %Plug.Conn{} = owner_conn = context.owner_conn
        conn = %{owner_conn | host: "customizable.metricflow.io"}
        {:ok, view, _html} = live(conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the client can interact with dashboard filter controls", context do
        html = render(context.view)

        has_filter_controls =
          has_element?(context.view, "[data-role='platform-filter']") or
            has_element?(context.view, "[data-role='date-range-filter']") or
            has_element?(context.view, "[data-role='metric-type-filter']") or
            html =~ "All Platforms"

        assert has_filter_controls,
               "Expected the client to have access to dashboard filter controls regardless of white-labeling. Got: #{html}"

        :ok
      end
    end

    scenario "dashboard functionality remains intact under white-label branding" do
      given_ :owner_with_integrations

      given_ "the client's account has white-labeling from an originating agency", context do
        user = MetricFlowTest.UsersFixtures.get_user_by_email(context.owner_email)
        account = MetricFlow.Repo.get_by!(MetricFlow.Accounts.Account, originator_user_id: user.id)

        agency = MetricFlowTest.AgenciesFixtures.agency_with_white_label_fixture(%{
          subdomain: "customizable2",
          logo_url: "https://example.com/agency-logo.png",
          primary_color: "#DD0000",
          secondary_color: "#0000DD"
        })

        MetricFlowTest.AgenciesFixtures.grant_agency_originator_access(agency.id, account.id)

        {:ok, Map.merge(context, %{agency: agency})}
      end

      given_ "the client visits the dashboard via the agency subdomain", context do
        %Plug.Conn{} = owner_conn = context.owner_conn
        conn = %{owner_conn | host: "customizable2.metricflow.io"}
        {:ok, view, _html} = live(conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the dashboard displays metrics data and charts as normal", context do
        html = render(context.view)

        has_dashboard_content =
          has_element?(context.view, "[data-role='metrics-dashboard']") or
            has_element?(context.view, "[data-role='stat-card']") or
            has_element?(context.view, "[data-role='metrics-area']") or
            html =~ "All Metrics"

        assert has_dashboard_content,
               "Expected the dashboard to display full metrics content regardless of white-labeling. Got: #{html}"

        :ok
      end
    end
  end
end
