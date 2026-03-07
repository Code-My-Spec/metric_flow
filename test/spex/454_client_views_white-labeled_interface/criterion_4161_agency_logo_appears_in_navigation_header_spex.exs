defmodule MetricFlowSpex.AgencyLogoAppearsInNavigationHeaderSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Agency logo appears in navigation header" do
    scenario "client sees agency logo in the navigation header when white-labeling is active" do
      given_ :user_logged_in_as_owner

      given_ "the client's account is originated by an agency with a logo configured", context do
        user = MetricFlowTest.UsersFixtures.get_user_by_email(context.owner_email)
        account = MetricFlow.Repo.get_by!(MetricFlow.Accounts.Account, originator_user_id: user.id)

        agency = MetricFlowTest.AgenciesFixtures.agency_with_white_label_fixture(%{
          subdomain: "logotest",
          logo_url: "https://example.com/my-agency-logo.png",
          primary_color: "#112233",
          secondary_color: "#445566"
        })

        MetricFlowTest.AgenciesFixtures.grant_agency_originator_access(agency.id, account.id)

        {:ok, Map.merge(context, %{agency: agency})}
      end

      given_ "the client navigates to the dashboard via the agency subdomain", context do
        %Plug.Conn{} = owner_conn = context.owner_conn
        conn = %{owner_conn | host: "logotest.metricflow.io"}
        {:ok, view, _html} = live(conn, "/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the navigation header displays the agency logo", context do
        html = render(context.view)

        has_agency_logo =
          has_element?(context.view, "[data-role='agency-logo']") or
            has_element?(context.view, "header img[src*='my-agency-logo']") or
            has_element?(context.view, "header [data-white-label-logo]") or
            html =~ "my-agency-logo.png"

        assert has_agency_logo,
               "Expected the navigation header to display the agency logo. Got: #{html}"

        :ok
      end
    end

    scenario "agency logo replaces or accompanies the default logo in the header" do
      given_ :user_logged_in_as_owner

      given_ "the client's account has an originating agency with branding", context do
        user = MetricFlowTest.UsersFixtures.get_user_by_email(context.owner_email)
        account = MetricFlow.Repo.get_by!(MetricFlow.Accounts.Account, originator_user_id: user.id)

        agency = MetricFlowTest.AgenciesFixtures.agency_with_white_label_fixture(%{
          subdomain: "logotest2",
          logo_url: "https://example.com/agency-brand.png",
          primary_color: "#AABB00",
          secondary_color: "#00BBAA"
        })

        MetricFlowTest.AgenciesFixtures.grant_agency_originator_access(agency.id, account.id)

        {:ok, Map.merge(context, %{agency: agency})}
      end

      given_ "the client visits the app via the agency subdomain", context do
        %Plug.Conn{} = owner_conn = context.owner_conn
        conn = %{owner_conn | host: "logotest2.metricflow.io"}
        {:ok, view, _html} = live(conn, "/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the header contains the agency logo image", context do
        html = render(context.view)

        has_logo_in_header =
          has_element?(context.view, "header [data-role='agency-logo']") or
            has_element?(context.view, "header img[src*='agency-brand']") or
            html =~ "agency-brand.png"

        assert has_logo_in_header,
               "Expected the header to contain the agency logo image element. Got: #{html}"

        :ok
      end
    end
  end
end
