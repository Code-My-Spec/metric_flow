defmodule MetricFlowSpex.Criterion179TheSystemStoresGoalMetricsPerAccountSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "The system stores goal metrics per account", criterion: 179 do
    scenario "a goal metric persists across sessions for the same account" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "the user has selected goal metrics for their account", context do
        MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{metric_name: "revenue"})
        MetricFlowSpex.Fixtures.set_goal_metric!(context.owner_email, "revenue")
        {:ok, context}
      end

      when_ "they return in a later session", context do
        {:ok, view, html} = live(context.owner_conn, "/app/correlations/goals")
        {:ok, Map.merge(context, %{view: view, html: html})}
      end

      then_ "the same goal metrics are still configured for that account", context do
        assert context.html =~ ~s(value="revenue" selected)
        {:ok, context}
      end
    end
  end
end
