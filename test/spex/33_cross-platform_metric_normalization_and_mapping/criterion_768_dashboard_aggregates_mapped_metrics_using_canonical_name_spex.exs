defmodule MetricFlowSpex.DashboardAggregatesMappedMetricsUsingCanonicalNameSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Dashboard aggregates mapped metrics using canonical name", criterion: 768 do
    scenario "a dashboard totals canonical clicks across two platforms into a single figure" do
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

      when_ "a dashboard totals canonical 'clicks' across platforms", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the total combines both platforms' clicks into a single aggregated figure",
            context do
        html = render(context.view)
        assert html =~ "50"
        {:ok, context}
      end
    end
  end
end
