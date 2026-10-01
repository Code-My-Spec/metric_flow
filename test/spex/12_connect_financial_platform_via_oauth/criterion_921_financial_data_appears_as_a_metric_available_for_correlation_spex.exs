defmodule MetricFlowSpex.FinancialDataAppearsAsAMetricAvailableForCorrelationSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Financial data appears as a metric available for correlation", criterion: 921 do
    scenario "a synced QuickBooks metric appears alongside a marketing metric in the goal picker" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "QuickBooks financial data has been synced", context do
        dt = DateTime.new!(Date.add(Date.utc_today(), -1), ~T[00:00:00], "Etc/UTC")

        MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{
          metric_name: "revenue",
          provider: :quickbooks,
          value: 1000.0,
          recorded_at: dt
        })

        MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{
          metric_name: "clicks",
          provider: :google_ads,
          value: 50.0,
          recorded_at: dt
        })

        {:ok, context}
      end

      when_ "a user views available metrics for correlation analysis", context do
        {:ok, goals_view, _html} = live(context.owner_conn, "/app/correlations/goals")
        {:ok, Map.put(context, :goals_view, goals_view)}
      end

      then_ "the financial data appears as just another metric, alongside marketing metrics", context do
        html = render(context.goals_view)
        assert html =~ "revenue"
        assert html =~ "clicks"
        {:ok, context}
      end
    end
  end
end
