defmodule MetricFlowSpex.CombinedTimeAndPlatformAggregationStillReDerivesRatherThanAveragingNestedValuesSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Combined time and platform aggregation still re-derives rather than averaging nested values",
    criterion: 759 do
    scenario "CPC aggregated across both multiple days and multiple platforms at once sums all components first" do
      given_(:user_logged_in_as_owner)

      given_ "a view aggregates CPC across both multiple days and multiple platforms at once",
             context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_ads)
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :facebook_ads)

        two_days_ago = DateTime.new!(Date.add(Date.utc_today(), -2), ~T[00:00:00], "Etc/UTC")
        one_day_ago = DateTime.new!(Date.add(Date.utc_today(), -1), ~T[00:00:00], "Etc/UTC")

        for {provider, recorded_at, cost, clicks} <- [
              {:google_ads, two_days_ago, 5.0, 0.5},
              {:google_ads, one_day_ago, 5.0, 50.0},
              {:facebook_ads, two_days_ago, 5.0, 0.5},
              {:facebook_ads, one_day_ago, 5.0, 50.0}
            ] do
          MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{
            provider: provider,
            metric_name: "total_cost",
            value: cost,
            recorded_at: recorded_at
          })

          MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{
            provider: provider,
            metric_name: "clicks",
            value: clicks,
            recorded_at: recorded_at
          })
        end

        {:ok, context}
      end

      when_ "the system computes the aggregated CPC", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "it sums all component spend and clicks across that combined scope first, rather than averaging each row's or each platform's already-derived CPC",
            context do
        html = render(context.view)
        total_cost = 5.0 + 5.0 + 5.0 + 5.0
        total_clicks = 0.5 + 50.0 + 0.5 + 50.0
        correct_cpc = :erlang.float_to_binary(total_cost / total_clicks, decimals: 1)
        naive_average_cpc = :erlang.float_to_binary((10.0 + 0.1 + 10.0 + 0.1) / 4, decimals: 1)

        assert html =~ correct_cpc
        refute html =~ naive_average_cpc
        {:ok, context}
      end
    end
  end
end
