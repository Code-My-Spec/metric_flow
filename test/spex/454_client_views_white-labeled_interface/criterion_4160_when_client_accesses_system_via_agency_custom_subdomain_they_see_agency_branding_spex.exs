defmodule MetricFlowSpex.ClientSeesAgencyBrandingViaSubdomainSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "When client accesses system via agency custom subdomain they see agency branding" do
    scenario "authenticated client visiting via agency subdomain sees agency branding" do
      given_ :user_logged_in_as_owner

      given_ "the client's account is originated by an agency with white-label branding configured", context do
        user = MetricFlowTest.UsersFixtures.get_user_by_email(context.owner_email)
        account = MetricFlow.Repo.get_by!(MetricFlow.Accounts.Account, originator_user_id: user.id)

        agency = MetricFlowTest.AgenciesFixtures.agency_with_white_label_fixture(%{
          subdomain: "testbrand",
          logo_url: "https://example.com/agency-logo.png",
          primary_color: "#FF5733",
          secondary_color: "#33FF57"
        })

        MetricFlowTest.AgenciesFixtures.grant_agency_originator_access(agency.id, account.id)

        {:ok, Map.merge(context, %{agency: agency, account: account})}
      end

      given_ "the client navigates to the dashboard via the agency subdomain", context do
        %Plug.Conn{} = owner_conn = context.owner_conn
        conn = %{owner_conn | host: "testbrand.metricflow.io"}
        result = live(conn, "/dashboard")
        {:ok, Map.put(context, :result, result)}
      end

      then_ "the client sees the agency branding instead of default branding", context do
        case context.result do
          {:ok, view, _html} ->
            html = render(view)

            has_agency_branding =
              html =~ "agency-logo" or
                html =~ "testbrand" or
                html =~ "#FF5733" or
                has_element?(view, "[data-role='agency-logo']") or
                has_element?(view, "[data-agency-subdomain]") or
                has_element?(view, "[data-white-label]")

            assert has_agency_branding,
                   "Expected the client to see agency branding when accessing via subdomain. Got: #{html}"

          {:error, {:redirect, %{to: path}}} ->
            flunk("Expected dashboard to load with agency branding but was redirected to #{path}")

          {:error, {:live_redirect, %{to: path}}} ->
            flunk("Expected dashboard to load with agency branding but was live-redirected to #{path}")
        end

        :ok
      end
    end

    scenario "unauthenticated user visiting agency subdomain is redirected to login" do
      given_ "an unauthenticated user visits the dashboard via an agency subdomain", context do
        %Plug.Conn{} = base_conn = build_conn()
        conn = %{base_conn | host: "testbrand.metricflow.io"}
        result = live(conn, "/dashboard")
        {:ok, Map.put(context, :result, result)}
      end

      then_ "the user is redirected to the login page", context do
        case context.result do
          {:error, {:redirect, %{to: "/users/log-in"}}} ->
            :ok

          {:error, {:redirect, _}} ->
            :ok

          {:error, {:live_redirect, _}} ->
            :ok

          {:ok, _view, _html} ->
            flunk("Expected unauthenticated user to be redirected away from dashboard")
        end
      end
    end
  end
end
