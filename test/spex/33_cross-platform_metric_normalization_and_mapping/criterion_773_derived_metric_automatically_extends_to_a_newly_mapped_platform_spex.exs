defmodule MetricFlowSpex.DerivedMetricAutomaticallyExtendsToANewlyMappedPlatformSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Derived metric automatically extends to a newly mapped platform", criterion: 773 do
    scenario "CPC automatically incorporates a newly mapped platform's spend and clicks without extra config" do
      given_(:user_logged_in_as_owner)

      given_ "a derived metric such as CPC defined in terms of canonical 'spend' and canonical 'clicks'",
             context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_ads)

        MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{
          provider: :google_ads,
          metric_name: "total_cost",
          value: 100.0
        })

        MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{
          provider: :google_ads,
          metric_name: "clicks",
          value: 20.0
        })

        {:ok, context}
      end

      when_ "a new platform's spend and clicks are mapped to those canonical metrics", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :facebook_ads)

        MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{
          provider: :facebook_ads,
          metric_name: "total_cost",
          value: 100.0
        })

        MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{
          provider: :facebook_ads,
          metric_name: "clicks",
          value: 30.0
        })

        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "CPC automatically computes for that platform without additional configuration",
            context do
        html = render(context.view)
        expected_cpc = :erlang.float_to_binary(200.0 / 50.0, decimals: 1)
        assert html =~ expected_cpc
        {:ok, context}
      end
    end
  end
end
