defmodule MetricFlowSpex.NoAndersonAnalyticsBrandingOnWhiteLabeledInstancesSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "No Anderson Analytics branding visible on white-labeled instances" do
    scenario "white-labeled dashboard does not show Anderson Analytics or MetricFlow brand text" do
      given_ :user_logged_in_as_owner

      given_ "an agency with white-label branding is configured as the account originator", context do
        user = MetricFlowTest.UsersFixtures.get_user_by_email(context.owner_email)
        account = MetricFlow.Repo.get_by!(MetricFlow.Accounts.Account, originator_user_id: user.id)

        agency = MetricFlowTest.AgenciesFixtures.agency_with_white_label_fixture(%{
          subdomain: "nodefaultbrand",
          logo_url: "https://cdn.clientbrand.com/logo.png",
          primary_color: "#1A2B3C",
          secondary_color: "#3C2B1A"
        })

        MetricFlowTest.AgenciesFixtures.grant_agency_originator_access(agency.id, account.id)

        {:ok, Map.merge(context, %{agency: agency, account: account})}
      end

      given_ "the client visits the dashboard via the agency subdomain", context do
        %Plug.Conn{} = owner_conn = context.owner_conn
        conn = %{owner_conn | host: "nodefaultbrand.metricflow.io"}
        {:ok, view, _html} = live(conn, "/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the rendered page does not contain Anderson Analytics brand text", context do
        html = render(context.view)

        refute html =~ "Anderson Analytics",
               "Expected white-labeled page to NOT show 'Anderson Analytics'. Got: #{html}"

        :ok
      end

      then_ "the rendered page does not show the default MetricFlow platform logo", context do
        refute has_element?(context.view, "[data-role='default-logo']"),
               "Expected white-labeled page to NOT show the default-logo element when white-labeling is active"

        :ok
      end

      then_ "the rendered page shows the agency logo instead", context do
        html = render(context.view)

        has_agency_logo =
          has_element?(context.view, "[data-role='agency-logo']") or
            html =~ "cdn.clientbrand.com/logo.png"

        assert has_agency_logo,
               "Expected white-labeled page to display the agency logo. Got: #{html}"

        :ok
      end
    end

    scenario "white-labeled account settings page does not show Anderson Analytics or MetricFlow brand text" do
      given_ :user_logged_in_as_owner

      given_ "an agency with white-label branding is configured as the account originator", context do
        user = MetricFlowTest.UsersFixtures.get_user_by_email(context.owner_email)
        account = MetricFlow.Repo.get_by!(MetricFlow.Accounts.Account, originator_user_id: user.id)

        agency = MetricFlowTest.AgenciesFixtures.agency_with_white_label_fixture(%{
          subdomain: "nobrandcheck",
          logo_url: "https://cdn.clientbrand.com/brand.png",
          primary_color: "#FF0000",
          secondary_color: "#0000FF"
        })

        MetricFlowTest.AgenciesFixtures.grant_agency_originator_access(agency.id, account.id)

        {:ok, Map.merge(context, %{agency: agency, account: account})}
      end

      given_ "the client visits the account settings page via the agency subdomain", context do
        %Plug.Conn{} = owner_conn = context.owner_conn
        conn = %{owner_conn | host: "nobrandcheck.metricflow.io"}
        {:ok, view, _html} = live(conn, "/accounts/settings")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the rendered page does not contain Anderson Analytics brand text", context do
        html = render(context.view)

        refute html =~ "Anderson Analytics",
               "Expected white-labeled settings page to NOT show 'Anderson Analytics'. Got: #{html}"

        :ok
      end

      then_ "the white-label indicator is present confirming branding is active", context do
        assert has_element?(context.view, "[data-white-label='true']") or
                 has_element?(context.view, "[data-white-label]"),
               "Expected the white-label branding indicator to be present on the page"

        :ok
      end
    end

    scenario "a page without white-label active on the main domain may show default platform branding" do
      given_ :user_logged_in_as_owner

      given_ "the owner visits the dashboard on the main (non-white-labeled) domain", context do
        {:ok, view, _html} = live(context.owner_conn, "/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the default logo is shown and no white-label agency logo overrides it", context do
        has_default_logo =
          has_element?(context.view, "[data-role='default-logo']") or
            render(context.view) =~ "logo.svg"

        has_no_white_label_active =
          not has_element?(context.view, "[data-white-label='true']")

        assert has_default_logo,
               "Expected the default logo to be present when not on a white-labeled subdomain"

        assert has_no_white_label_active,
               "Expected no white-label indicator when accessing via the main domain"

        :ok
      end

      then_ "no Anderson Analytics branding appears on the main domain dashboard either", context do
        html = render(context.view)

        refute html =~ "Anderson Analytics",
               "Expected the main domain dashboard to NOT contain 'Anderson Analytics'. Got: #{html}"

        :ok
      end
    end
  end
end
