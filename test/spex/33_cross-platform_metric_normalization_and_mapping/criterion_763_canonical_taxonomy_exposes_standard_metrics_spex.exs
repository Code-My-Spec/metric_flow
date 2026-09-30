defmodule MetricFlowSpex.CanonicalTaxonomyExposesStandardMetricsSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Canonical taxonomy exposes standard metrics", criterion: 763 do
    scenario "the canonical taxonomy includes clicks, spend, impressions, and conversions" do
      given_(:user_logged_in_as_owner)

      given_ "metrics recorded under each canonical name", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_ads)

        for name <- ["clicks", "total_cost", "impressions", "conversions"] do
          MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{
            provider: :google_ads,
            metric_name: name,
            value: 10.0
          })
        end

        {:ok, context}
      end

      when_ "an administrator or integration looks up canonical metrics", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "clicks, spend, impressions, and conversions are available as canonical metric definitions",
            context do
        html = render(context.view)
        assert html =~ "clicks"
        assert html =~ "total_cost"
        assert html =~ "impressions"
        assert html =~ "conversions"
        {:ok, context}
      end
    end
  end
end
