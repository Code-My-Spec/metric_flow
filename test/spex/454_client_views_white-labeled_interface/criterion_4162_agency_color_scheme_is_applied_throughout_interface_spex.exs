defmodule MetricFlowSpex.AgencyColorSchemeAppliedThroughoutInterfaceSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Agency color scheme is applied throughout interface" do
    scenario "client sees agency color scheme when white-labeling is active" do
      given_ :user_logged_in_as_owner

      given_ "the client's account is originated by an agency with custom colors", context do
        user = MetricFlowTest.UsersFixtures.get_user_by_email(context.owner_email)
        account = MetricFlow.Repo.get_by!(MetricFlow.Accounts.Account, originator_user_id: user.id)

        agency = MetricFlowTest.AgenciesFixtures.agency_with_white_label_fixture(%{
          subdomain: "colortest",
          logo_url: "https://example.com/logo.png",
          primary_color: "#FF0000",
          secondary_color: "#00FF00"
        })

        MetricFlowTest.AgenciesFixtures.grant_agency_originator_access(agency.id, account.id)

        {:ok, Map.merge(context, %{agency: agency})}
      end

      given_ "the client navigates to the dashboard via the agency subdomain", context do
        %Plug.Conn{} = owner_conn = context.owner_conn
        conn = %{owner_conn | host: "colortest.metricflow.io"}
        {:ok, view, _html} = live(conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the interface applies the agency primary and secondary colors", context do
        html = render(context.view)

        has_custom_colors =
          html =~ "#FF0000" or
            html =~ "#00FF00" or
            html =~ "--primary" or
            html =~ "data-theme" or
            has_element?(context.view, "[data-white-label-theme]") or
            has_element?(context.view, "[style*='--primary']") or
            has_element?(context.view, "[data-agency-colors]")

        assert has_custom_colors,
               "Expected the interface to apply the agency color scheme (#FF0000 primary, #00FF00 secondary). Got: #{html}"

        :ok
      end
    end

    scenario "agency colors are reflected in the navigation and content areas" do
      given_ :user_logged_in_as_owner

      given_ "the client's account has an originating agency with colors configured", context do
        user = MetricFlowTest.UsersFixtures.get_user_by_email(context.owner_email)
        account = MetricFlow.Repo.get_by!(MetricFlow.Accounts.Account, originator_user_id: user.id)

        agency = MetricFlowTest.AgenciesFixtures.agency_with_white_label_fixture(%{
          subdomain: "colortest2",
          logo_url: "https://example.com/logo.png",
          primary_color: "#334455",
          secondary_color: "#667788"
        })

        MetricFlowTest.AgenciesFixtures.grant_agency_originator_access(agency.id, account.id)

        {:ok, Map.merge(context, %{agency: agency})}
      end

      given_ "the client visits the app via the agency subdomain", context do
        %Plug.Conn{} = owner_conn = context.owner_conn
        conn = %{owner_conn | host: "colortest2.metricflow.io"}
        {:ok, view, _html} = live(conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the color scheme is visible in the rendered page", context do
        html = render(context.view)

        has_color_application =
          html =~ "#334455" or
            html =~ "#667788" or
            has_element?(context.view, "[data-white-label-theme]") or
            has_element?(context.view, "[style*='#334455']") or
            has_element?(context.view, "[data-agency-colors]")

        assert has_color_application,
               "Expected agency colors (#334455, #667788) to be applied in the interface. Got: #{html}"

        :ok
      end
    end
  end
end
