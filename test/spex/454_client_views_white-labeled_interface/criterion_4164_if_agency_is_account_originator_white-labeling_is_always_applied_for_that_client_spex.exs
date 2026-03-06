defmodule MetricFlowSpex.AgencyOriginatorWhiteLabelingAlwaysAppliedSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "If agency is account originator white-labeling is always applied for that client" do
    scenario "client originated by an agency always sees agency branding on agency subdomain" do
      given_ :user_logged_in_as_owner

      given_ "the client's account was originated by an agency with white-label branding", context do
        user = MetricFlowTest.UsersFixtures.get_user_by_email(context.owner_email)
        account = MetricFlow.Repo.get_by!(MetricFlow.Accounts.Account, originator_user_id: user.id)

        agency = MetricFlowTest.AgenciesFixtures.agency_with_white_label_fixture(%{
          subdomain: "originator",
          logo_url: "https://example.com/originator-logo.png",
          primary_color: "#DEADBE",
          secondary_color: "#BEEFCA"
        })

        MetricFlowTest.AgenciesFixtures.grant_agency_originator_access(agency.id, account.id)

        {:ok, Map.merge(context, %{agency: agency, account: account})}
      end

      given_ "the client accesses the dashboard via the agency subdomain", context do
        conn = %Plug.Conn{context.owner_conn | host: "originator.metricflow.io"}
        {:ok, view, _html} = live(conn, "/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the agency branding is visible because originator status ensures white-labeling", context do
        html = render(context.view)

        has_originator_branding =
          html =~ "originator-logo.png" or
            html =~ "#DEADBE" or
            has_element?(context.view, "[data-role='agency-logo']") or
            has_element?(context.view, "[data-white-label]") or
            has_element?(context.view, "[data-agency-subdomain='originator']")

        assert has_originator_branding,
               "Expected originator agency branding to always be applied for the client. Got: #{html}"

        :ok
      end
    end

    scenario "originator branding persists across different pages" do
      given_ :user_logged_in_as_owner

      given_ "the client's account was originated by an agency with branding", context do
        user = MetricFlowTest.UsersFixtures.get_user_by_email(context.owner_email)
        account = MetricFlow.Repo.get_by!(MetricFlow.Accounts.Account, originator_user_id: user.id)

        agency = MetricFlowTest.AgenciesFixtures.agency_with_white_label_fixture(%{
          subdomain: "originator2",
          logo_url: "https://example.com/persistent-logo.png",
          primary_color: "#112233",
          secondary_color: "#445566"
        })

        MetricFlowTest.AgenciesFixtures.grant_agency_originator_access(agency.id, account.id)

        {:ok, Map.merge(context, %{agency: agency})}
      end

      given_ "the client navigates to their account settings via the agency subdomain", context do
        conn = %Plug.Conn{context.owner_conn | host: "originator2.metricflow.io"}
        {:ok, view, _html} = live(conn, "/accounts/settings")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the agency branding is still present on the settings page", context do
        html = render(context.view)

        has_branding_on_settings =
          html =~ "persistent-logo.png" or
            has_element?(context.view, "[data-role='agency-logo']") or
            has_element?(context.view, "[data-white-label]") or
            has_element?(context.view, "[data-agency-subdomain]")

        assert has_branding_on_settings,
               "Expected originator agency branding to persist on the account settings page. Got: #{html}"

        :ok
      end
    end
  end
end
