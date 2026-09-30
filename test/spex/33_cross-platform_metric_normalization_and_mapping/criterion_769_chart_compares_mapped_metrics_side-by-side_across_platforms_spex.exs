defmodule MetricFlowSpex.ChartComparesMappedMetricsSideBySideAcrossPlatformsSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Chart compares mapped metrics side-by-side across platforms", criterion: 769 do
    scenario "a comparison chart displays each platform's clicks as a separate series" do
      given_(:user_logged_in_as_owner)

      given_ "Google Ads clicks and Facebook Ads clicks both mapped to canonical 'clicks'",
             context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_ads)
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :facebook_ads)

        MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{
          provider: :google_ads,
          metric_name: "clicks",
          value: 30.0
        })

        MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{
          provider: :facebook_ads,
          metric_name: "clicks",
          value: 20.0
        })

        {:ok, context}
      end

      when_ "a user views a comparison chart for canonical 'clicks'", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the chart displays each platform's clicks as a separate series for direct comparison",
            context do
        chart_spec =
          context.view
          |> element("[data-role='vega-lite-chart']")
          |> render()

        assert chart_spec =~ "google_ads" and chart_spec =~ "facebook_ads",
               "Expected the chart spec to encode a series per platform for the canonical 'clicks' comparison, got: #{chart_spec}"

        {:ok, context}
      end
    end
  end
end
