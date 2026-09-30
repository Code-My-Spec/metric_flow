defmodule MetricFlowSpex.SubdomainActivatesOnceDnsVerificationSucceedsSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  alias MetricFlowTest.AgenciesFixtures

  spex "Subdomain activates once DNS verification succeeds", criterion: 743 do
    scenario "a client accessing a verified white-label subdomain sees the agency's branding" do
      given_(:user_logged_in_as_owner)

      given_ "a custom subdomain has been configured and DNS verification succeeds", context do
        account = MetricFlowSpex.Fixtures.account_originated_by(context.owner_email)

        agency =
          AgenciesFixtures.agency_with_white_label_fixture(%{
            subdomain: "verified743",
            logo_url: "https://cdn.clientbrand.com/logo.png",
            primary_color: "#1A2B3C",
            secondary_color: "#3C2B1A",
            subdomain_verified_at: DateTime.utc_now() |> DateTime.truncate(:second)
          })

        AgenciesFixtures.grant_agency_originator_access(agency.id, account.id)

        {:ok, Map.merge(context, %{agency: agency, account: account})}
      end

      when_ "verification completes and the client visits the dashboard via that subdomain",
            context do
        %Plug.Conn{} = owner_conn = context.owner_conn
        conn = %{owner_conn | host: "verified743.metricflow.io"}
        {:ok, view, _html} = live(conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the subdomain is active and serves white-labeled reports", context do
        html = render(context.view)

        assert has_element?(context.view, "[data-white-label='true']") or
                 html =~ "cdn.clientbrand.com/logo.png",
               "Expected the verified subdomain to serve white-labeled content, got: #{html}"

        {:ok, context}
      end
    end
  end
end
