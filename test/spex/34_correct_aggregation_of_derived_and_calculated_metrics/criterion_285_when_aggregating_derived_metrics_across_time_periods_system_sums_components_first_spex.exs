defmodule MetricFlowSpex.AggregatingDerivedMetricsAcrossTimePeriodsSumsComponentsFirstSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "When aggregating derived metrics across time periods, system sums the component metrics first then calculates the derived value from the aggregated components",
    criterion: 285 do
    scenario "CPC rolled up across two days is derived from summed spend and clicks, not averaged daily CPCs" do
      given_(:user_logged_in_as_owner)

      given_ "spend and clicks are recorded on two different days within the range", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_ads)

        two_days_ago = DateTime.new!(Date.add(Date.utc_today(), -2), ~T[00:00:00], "Etc/UTC")
        one_day_ago = DateTime.new!(Date.add(Date.utc_today(), -1), ~T[00:00:00], "Etc/UTC")

        MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{
          provider: :google_ads,
          metric_name: "total_cost",
          value: 10.0,
          recorded_at: two_days_ago
        })

        MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{
          provider: :google_ads,
          metric_name: "clicks",
          value: 1.0,
          recorded_at: two_days_ago
        })

        MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{
          provider: :google_ads,
          metric_name: "total_cost",
          value: 10.0,
          recorded_at: one_day_ago
        })

        MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{
          provider: :google_ads,
          metric_name: "clicks",
          value: 100.0,
          recorded_at: one_day_ago
        })

        {:ok, context}
      end

      when_ "the user views CPC rolled up to the last 7 days", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the system sums the week's spend and clicks first, then computes CPC from those sums",
            context do
        html = render(context.view)
        correct_cpc = :erlang.float_to_binary(20.0 / 101.0, decimals: 1)
        naive_average_cpc = :erlang.float_to_binary((10.0 + 0.1) / 2, decimals: 1)

        assert html =~ correct_cpc,
               "Expected CPC derived from summed components (#{correct_cpc}), got: #{html}"

        refute html =~ naive_average_cpc,
               "Expected CPC to NOT be a naive average of daily CPCs (#{naive_average_cpc})"

        {:ok, context}
      end
    end
  end
end
