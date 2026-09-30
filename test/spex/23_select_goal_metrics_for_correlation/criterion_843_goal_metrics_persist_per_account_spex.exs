defmodule MetricFlowSpex.Criterion843GoalMetricsPersistPerAccountSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Goal metrics persist per account", criterion: 843 do
    scenario "a user's goal metrics are still configured when they return in a later session" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "a user has selected goal metrics for their account", context do
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
