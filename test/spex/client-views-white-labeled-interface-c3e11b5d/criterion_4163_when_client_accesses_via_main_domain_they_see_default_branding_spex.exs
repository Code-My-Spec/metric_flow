defmodule MetricFlowSpex.ClientSeesDefaultBrandingViaMainDomainSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "When client accesses via main domain they see default branding" do
    scenario "client visiting via main domain sees default MetricFlow branding" do
      given_ :user_logged_in_as_owner

      given_ "the client's account is originated by an agency with white-label config", context do
        user = MetricFlowTest.UsersFixtures.get_user_by_email(context.owner_email)
        account = MetricFlow.Repo.get_by!(MetricFlow.Accounts.Account, originator_user_id: user.id)

        agency = MetricFlowTest.AgenciesFixtures.agency_with_white_label_fixture(%{
          subdomain: "agencymain",
          logo_url: "https://example.com/agency-logo.png",
          primary_color: "#AA1122",
          secondary_color: "#22AA11"
        })

        MetricFlowTest.AgenciesFixtures.grant_agency_originator_access(agency.id, account.id)

        {:ok, Map.merge(context, %{agency: agency})}
      end

      given_ "the client navigates to the dashboard via the main domain", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the client sees default branding, not agency branding", context do
        html = render(context.view)

        sees_default_branding =
          has_element?(context.view, "img[src*='logo.svg']") or
            html =~ "logo.svg" or
            has_element?(context.view, "[data-role='default-logo']")

        does_not_see_agency_branding =
          not (html =~ "agency-logo.png") and
            not has_element?(context.view, "[data-role='agency-logo']")

        assert sees_default_branding,
               "Expected the client to see default MetricFlow branding on the main domain. Got: #{html}"

        assert does_not_see_agency_branding,
               "Expected the client NOT to see agency branding on the main domain. Got: #{html}"

        :ok
      end
    end

    scenario "default branding uses standard colors without agency customization" do
      given_ :user_logged_in_as_owner

      given_ "the client navigates to the dashboard on the main domain", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the interface uses default theme colors without agency overrides", context do
        html = render(context.view)

        has_no_agency_color_overrides =
          not (has_element?(context.view, "[data-white-label-theme]") or
                 has_element?(context.view, "[data-agency-colors]"))

        assert has_no_agency_color_overrides,
               "Expected the interface to use default theme colors without agency overrides. Got: #{html}"

        :ok
      end
    end

    scenario "unauthenticated user on main domain sees default branding" do
      given_ "an unauthenticated user visits the home page on the main domain", context do
        resp = get(build_conn(), "/")
        {:ok, Map.put(context, :resp, resp)}
      end

      then_ "the page shows default MetricFlow branding", context do
        html = context.resp.resp_body

        has_default_branding =
          html =~ "logo.svg" or
            html =~ "MetricFlow" or
            html =~ "metric_flow"

        assert has_default_branding,
               "Expected the home page to show default MetricFlow branding. Got: #{html}"

        :ok
      end
    end
  end
end
