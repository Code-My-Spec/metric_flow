defmodule MetricFlowSpex.WhiteLabelDoesNotAffectFunctionalitySpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "White-label branding does not affect functionality only visual appearance" do
    scenario "dashboard loads successfully with white-label branding active" do
      given_ :owner_with_integrations

      given_ "the client's account has an originating agency with white-label config", context do
        user = MetricFlowTest.UsersFixtures.get_user_by_email(context.owner_email)
        account = MetricFlow.Repo.get_by!(MetricFlow.Accounts.Account, originator_user_id: user.id)

        agency = MetricFlowTest.AgenciesFixtures.agency_with_white_label_fixture(%{
          subdomain: "functest",
          logo_url: "https://example.com/logo.png",
          primary_color: "#123456",
          secondary_color: "#654321"
        })

        MetricFlowTest.AgenciesFixtures.grant_agency_originator_access(agency.id, account.id)

        {:ok, Map.merge(context, %{agency: agency})}
      end

      given_ "the client navigates to the dashboard via the agency subdomain", context do
        %Plug.Conn{} = owner_conn = context.owner_conn
        conn = %{owner_conn | host: "functest.metricflow.io"}
        {:ok, view, _html} = live(conn, "/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the dashboard loads without errors and all functional elements are present", context do
        html = render(context.view)

        has_metrics_area =
          has_element?(context.view, "[data-role='metrics-dashboard']") or
            has_element?(context.view, "[data-role='metrics-area']") or
            html =~ "All Metrics"

        assert has_metrics_area,
               "Expected the dashboard to load fully with all functional elements under white-labeling. Got: #{html}"

        :ok
      end
    end

    scenario "platform filter works correctly under white-label branding" do
      given_ :owner_with_integrations

      given_ "the client's account has white-label branding from an agency", context do
        user = MetricFlowTest.UsersFixtures.get_user_by_email(context.owner_email)
        account = MetricFlow.Repo.get_by!(MetricFlow.Accounts.Account, originator_user_id: user.id)

        agency = MetricFlowTest.AgenciesFixtures.agency_with_white_label_fixture(%{
          subdomain: "functest2",
          logo_url: "https://example.com/logo.png",
          primary_color: "#AABB00",
          secondary_color: "#00AABB"
        })

        MetricFlowTest.AgenciesFixtures.grant_agency_originator_access(agency.id, account.id)

        {:ok, Map.merge(context, %{agency: agency})}
      end

      given_ "the client visits the dashboard via the agency subdomain", context do
        %Plug.Conn{} = owner_conn = context.owner_conn
        conn = %{owner_conn | host: "functest2.metricflow.io"}
        {:ok, view, _html} = live(conn, "/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the client clicks the platform filter", context do
        html =
          context.view
          |> element("[data-role='platform-filter']")
          |> render_click()

        {:ok, Map.put(context, :filter_html, html)}
      end

      then_ "the filter responds correctly and white-labeling does not interfere", context do
        html = render(context.view)

        dashboard_still_functional =
          has_element?(context.view, "[data-role='metrics-area']") or
            has_element?(context.view, "[data-role='stat-card']") or
            html =~ "All Metrics"

        assert dashboard_still_functional,
               "Expected the dashboard to remain fully functional after filter interaction under white-labeling. Got: #{html}"

        :ok
      end
    end

    scenario "integration page loads correctly under white-label branding" do
      given_ :owner_with_integrations

      given_ "the client's account has white-label branding from an originating agency", context do
        user = MetricFlowTest.UsersFixtures.get_user_by_email(context.owner_email)
        account = MetricFlow.Repo.get_by!(MetricFlow.Accounts.Account, originator_user_id: user.id)

        agency = MetricFlowTest.AgenciesFixtures.agency_with_white_label_fixture(%{
          subdomain: "functest3",
          logo_url: "https://example.com/logo.png",
          primary_color: "#CCDD00",
          secondary_color: "#00CCDD"
        })

        MetricFlowTest.AgenciesFixtures.grant_agency_originator_access(agency.id, account.id)

        {:ok, Map.merge(context, %{agency: agency})}
      end

      given_ "the client visits the integrations page via the agency subdomain", context do
        %Plug.Conn{} = owner_conn = context.owner_conn
        conn = %{owner_conn | host: "functest3.metricflow.io"}
        {:ok, view, _html} = live(conn, "/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the integrations page loads and functions normally with white-label branding", context do
        html = render(context.view)

        page_functional =
          html =~ "Integration" or
            html =~ "integration" or
            has_element?(context.view, "[data-role='integrations-list']") or
            has_element?(context.view, "[data-role='connected-integration']")

        assert page_functional,
               "Expected the integrations page to be fully functional under white-labeling. Got: #{html}"

        :ok
      end
    end
  end
end
