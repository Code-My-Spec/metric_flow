defmodule MetricFlowSpex.ComparisonWarnsOfKnownSemanticDifferencesSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Comparison warns of known semantic differences", criterion: 770 do
    scenario "comparing Google Ads and Facebook Ads clicks displays an attribution-window warning" do
      given_(:user_logged_in_as_owner)

      given_ "Google Ads clicks and Facebook Ads clicks use different attribution windows",
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

      when_ "a user compares the two platforms' clicks", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the comparison displays a warning or footnote noting the semantic difference",
            context do
        assert has_element?(context.view, "[data-role='semantic-warning']")
        {:ok, context}
      end
    end
  end
end
