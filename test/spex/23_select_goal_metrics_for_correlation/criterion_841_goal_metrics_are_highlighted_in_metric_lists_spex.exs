defmodule MetricFlowSpex.Criterion841GoalMetricsAreHighlightedInMetricListsSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Goal metrics are highlighted in metric lists", criterion: 841 do
    scenario "a metric selected as a goal is highlighted when viewed elsewhere in the application" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "a metric has been selected as a goal", context do
        MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{metric_name: "revenue"})
        MetricFlowSpex.Fixtures.set_goal_metric!(context.owner_email, "revenue")
        {:ok, context}
      end

      when_ "a user views metric lists elsewhere in the application", context do
        {:ok, view, html} = live(context.owner_conn, "/app/visualizations/new")
        {:ok, Map.merge(context, %{view: view, html: html})}
      end

      then_ "that metric is highlighted or badged to indicate it is a goal", context do
        assert has_element?(context.view, "[data-role='goal-metric-badge']"),
               "Expected the goal metric to be highlighted or badged in the metric list"

        {:ok, context}
      end
    end
  end
end
