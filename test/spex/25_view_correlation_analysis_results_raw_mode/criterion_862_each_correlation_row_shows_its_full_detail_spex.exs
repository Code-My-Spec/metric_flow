defmodule MetricFlowSpex.Criterion862EachCorrelationRowShowsItsFullDetailSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Each correlation row shows its full detail", criterion: 862 do
    scenario "a correlation row displays its metric name, coefficient, lag, and analyzed time period" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "a correlation appears in the Raw mode list", context do
        MetricFlowSpex.Fixtures.create_correlation_result!(context.owner_email, %{
          metric_name: "page_views",
          goal_metric_name: "revenue",
          coefficient: 0.61,
          optimal_lag: 3
        })

        {:ok, view, _html} = live(context.owner_conn, "/app/correlations")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a user views that row", context do
        {:ok, context}
      end

      then_ "it shows the metric name, correlation coefficient, optimal lag in days, and the time period analyzed", context do
        row_html =
          context.view
          |> element("[data-role='correlation-row'][data-metric='page_views']")
          |> render()

        assert row_html =~ "page_views"
        assert row_html =~ "0.61" or row_html =~ "61"
        assert row_html =~ "3 days"

        assert has_element?(context.view, "[data-role='data-window']"),
               "Expected the analyzed time period to be displayed"

        {:ok, context}
      end
    end
  end
end
