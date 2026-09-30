defmodule MetricFlowSpex.AggregatingDerivedMetricsAcrossMultiplePlatformsSumsComponentsFirstSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "When aggregating derived metrics across multiple platforms or ad accounts, system sums the component metrics first then calculates the derived value from the aggregated components",
    criterion: 286 do
    scenario "CPC aggregated across two platforms is derived from summed spend and clicks, not averaged per-platform CPCs" do
      given_(:user_logged_in_as_owner)

      given_ "spend and clicks are recorded on two different platforms", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_ads)
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :facebook_ads)

        MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{
          provider: :google_ads,
          metric_name: "total_cost",
          value: 10.0
        })

        MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{
          provider: :google_ads,
          metric_name: "clicks",
          value: 1.0
        })

        MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{
          provider: :facebook_ads,
          metric_name: "total_cost",
          value: 10.0
        })

        MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{
          provider: :facebook_ads,
          metric_name: "clicks",
          value: 100.0
        })

        {:ok, context}
      end

      when_ "the user views CPC aggregated across both platforms", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the system sums spend and clicks across platforms first, then computes CPC from those sums",
            context do
        html = render(context.view)
        correct_cpc = :erlang.float_to_binary(20.0 / 101.0, decimals: 1)
        naive_average_cpc = :erlang.float_to_binary((10.0 + 0.1) / 2, decimals: 1)

        assert html =~ correct_cpc,
               "Expected CPC derived from summed components (#{correct_cpc}), got: #{html}"

        refute html =~ naive_average_cpc,
               "Expected CPC to NOT be a naive average of per-platform CPCs (#{naive_average_cpc})"

        {:ok, context}
      end
    end
  end
end
