defmodule MetricFlowSpex.Criterion830WhiteLabelBrandingChangesAppearanceOnlySpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "White-label branding changes appearance only, not functionality", criterion: 830 do
    scenario "the same features are available under white-labeled and default branding, differing only visually" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_metrics

      given_ "a client viewing a white-labeled interface", context do
        account = MetricFlowSpex.Fixtures.account_originated_by(context.owner_email)

        agency =
          MetricFlowTest.AgenciesFixtures.agency_with_white_label_fixture(%{
            subdomain: "branded830",
            logo_url: "https://example.com/branded830-logo.png",
            primary_color: "#0F0F0F",
            secondary_color: "#F0F0F0"
          })

        MetricFlowTest.AgenciesFixtures.grant_agency_originator_access(agency.id, account.id)

        %Plug.Conn{} = owner_conn = context.owner_conn
        {:ok, Map.put(context, :agency_conn, %{owner_conn | host: "branded830.metricflow.io"})}
      end

      when_ "compared to the same client viewing default branding", context do
        {:ok, white_labeled_view, _html} = live(context.agency_conn, "/app/dashboard")
        {:ok, default_view, _html} = live(context.owner_conn, "/app/dashboard")

        {:ok, Map.merge(context, %{white_labeled_view: white_labeled_view, default_view: default_view})}
      end

      then_ "the available features and functionality are identical; only the visual appearance differs", context do
        assert has_element?(context.white_labeled_view, "[data-role='agency-logo']")
        refute has_element?(context.default_view, "[data-role='agency-logo']")

        assert has_element?(context.white_labeled_view, "nav") == has_element?(context.default_view, "nav")

        {:ok, context}
      end
    end
  end
end
