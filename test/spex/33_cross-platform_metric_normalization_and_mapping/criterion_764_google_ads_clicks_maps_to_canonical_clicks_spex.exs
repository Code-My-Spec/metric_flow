defmodule MetricFlowSpex.GoogleAdsClicksMapsToCanonicalClicksSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Google Ads Clicks maps to canonical clicks", criterion: 764 do
    scenario "a Google Ads clicks metric appears under the canonical clicks name on the dashboard" do
      given_(:user_logged_in_as_owner)

      given_ "the Google Ads integration's metric mapping", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_ads)
        {:ok, context}
      end

      when_ "the native metric 'Clicks' is synced", context do
        MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{
          provider: :google_ads,
          metric_name: "clicks",
          value: 42.0
        })

        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "it is mapped to the canonical metric 'clicks'", context do
        assert has_element?(context.view, "[data-role='stat-card']", "clicks")
        html = render(context.view)
        assert html =~ "42"
        {:ok, context}
      end
    end
  end
end
