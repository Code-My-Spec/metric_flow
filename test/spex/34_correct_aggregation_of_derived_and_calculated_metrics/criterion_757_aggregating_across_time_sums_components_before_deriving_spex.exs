defmodule MetricFlowSpex.AggregatingAcrossTimeSumsComponentsBeforeDerivingSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Aggregating across time sums components before deriving", criterion: 757 do
    scenario "CPC rolled up to a week sums the week's spend and clicks first, then computes CPC from those sums" do
      given_(:user_logged_in_as_owner)

      given_ "daily spend and clicks for a week", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_ads)

        two_days_ago = DateTime.new!(Date.add(Date.utc_today(), -2), ~T[00:00:00], "Etc/UTC")
        one_day_ago = DateTime.new!(Date.add(Date.utc_today(), -1), ~T[00:00:00], "Etc/UTC")

        for {recorded_at, cost, clicks} <- [{two_days_ago, 10.0, 1.0}, {one_day_ago, 10.0, 100.0}] do
          MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{
            provider: :google_ads,
            metric_name: "total_cost",
            value: cost,
            recorded_at: recorded_at
          })

          MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{
            provider: :google_ads,
            metric_name: "clicks",
            value: clicks,
            recorded_at: recorded_at
          })
        end

        {:ok, context}
      end

      when_ "the user views CPC rolled up to that week", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the system sums the week's spend and clicks first, then computes CPC from those sums",
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
