defmodule MetricFlowSpex.AggregatingAcrossPlatformsSumsComponentsBeforeDerivingSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Aggregating across platforms sums components before deriving", criterion: 758 do
    scenario "CPC aggregated across platforms sums spend and clicks across platforms first, then computes CPC" do
      given_(:user_logged_in_as_owner)

      given_ "spend and clicks from multiple connected platforms", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_ads)
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :facebook_ads)

        for {provider, cost, clicks} <- [{:google_ads, 10.0, 1.0}, {:facebook_ads, 10.0, 100.0}] do
          MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{
            provider: provider,
            metric_name: "total_cost",
            value: cost
          })

          MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{
            provider: provider,
            metric_name: "clicks",
            value: clicks
          })
        end

        {:ok, context}
      end

      when_ "the user views CPC aggregated across those platforms", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the system sums the spend and clicks across platforms first, then computes CPC from those sums",
            context do
        html = render(context.view)
        correct_cpc = :erlang.float_to_binary(20.0 / 101.0, decimals: 1)
        naive_average_cpc = :erlang.float_to_binary((10.0 + 0.1) / 2, decimals: 1)

        assert html =~ correct_cpc
        refute html =~ naive_average_cpc
        {:ok, context}
      end
    end
  end
end
