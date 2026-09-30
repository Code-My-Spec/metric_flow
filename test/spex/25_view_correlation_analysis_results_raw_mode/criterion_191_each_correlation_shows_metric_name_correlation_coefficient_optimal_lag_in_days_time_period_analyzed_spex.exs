defmodule MetricFlowSpex.Criterion191EachCorrelationShowsMetricNameCoefficientOptimalLagTimePeriodAnalyzedSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Each correlation shows: metric name, correlation coefficient, optimal lag in days, time period analyzed",
    criterion: 191 do
    scenario "a correlation row shows its metric name, coefficient, lag, and the analyzed time period" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "a calculated correlation with a known metric name, coefficient, and lag", context do
        MetricFlowSpex.Fixtures.create_correlation_result!(context.owner_email, %{
          metric_name: "ad_spend",
          goal_metric_name: "revenue",
          coefficient: 0.72,
          optimal_lag: 5
        })

        {:ok, view, _html} = live(context.owner_conn, "/app/correlations")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a user views that correlation in Raw mode", context do
        {:ok, context}
      end

      then_ "the row shows the metric name, coefficient, optimal lag in days, and the analyzed time period", context do
        row_html =
          context.view
          |> element("[data-role='correlation-row'][data-metric='ad_spend']")
          |> render()

        assert row_html =~ "ad_spend"
        assert row_html =~ "0.72" or row_html =~ "72"
        assert row_html =~ "5 days"

        assert has_element?(context.view, "[data-role='data-window']"),
               "Expected the analyzed time period to be displayed"

        {:ok, context}
      end
    end
  end
end
