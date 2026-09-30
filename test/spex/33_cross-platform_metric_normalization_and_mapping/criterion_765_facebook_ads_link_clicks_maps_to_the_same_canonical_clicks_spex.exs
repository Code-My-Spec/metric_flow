defmodule MetricFlowSpex.FacebookAdsLinkClicksMapsToTheSameCanonicalClicksSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Facebook Ads Link Clicks maps to the same canonical clicks", criterion: 765 do
    scenario "Facebook Ads link clicks are aggregated into the same canonical clicks total as Google Ads clicks" do
      given_(:user_logged_in_as_owner)

      given_ "the Facebook Ads integration's metric mapping, alongside an existing Google Ads clicks metric",
             context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_ads)
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :facebook_ads)

        MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{
          provider: :google_ads,
          metric_name: "clicks",
          value: 10.0
        })

        {:ok, context}
      end

      when_ "the native metric 'Link Clicks' is synced", context do
        MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{
          provider: :facebook_ads,
          metric_name: "clicks",
          value: 25.0
        })

        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "it is mapped to the canonical metric 'clicks', the same canonical metric Google Ads 'Clicks' maps to",
            context do
        html = render(context.view)
        assert html =~ "35"
        {:ok, context}
      end
    end
  end
end
