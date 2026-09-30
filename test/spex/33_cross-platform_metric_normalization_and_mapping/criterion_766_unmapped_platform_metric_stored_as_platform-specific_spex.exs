defmodule MetricFlowSpex.UnmappedPlatformMetricStoredAsPlatformSpecificSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Unmapped platform metric stored as platform-specific", criterion: 766 do
    scenario "a platform metric with no canonical equivalent is clearly labeled as platform-specific" do
      given_(:user_logged_in_as_owner)

      given_ "a platform metric with no direct canonical equivalent", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_ads)
        {:ok, context}
      end

      when_ "it is synced into the system", context do
        MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{
          provider: :google_ads,
          metric_name: "custom_audience_overlap_score",
          value: 7.0
        })

        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "it is stored as a platform-specific metric and clearly labeled as such rather than mapped to a canonical metric",
            context do
        assert has_element?(
                 context.view,
                 "[data-role='stat-card'][data-metric-scope='platform-specific']",
                 "custom_audience_overlap_score"
               ),
               "Expected the unmapped metric to be clearly labeled as platform-specific, distinct from canonical metrics"

        {:ok, context}
      end
    end
  end
end
