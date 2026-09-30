defmodule MetricFlowSpex.Criterion838UserOpensGoalMetricsConfigurationFromTheMenuSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "User opens Goal Metrics configuration from the menu", criterion: 838 do
    scenario "a user viewing the application menu selects Goal Metrics configuration" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "a user viewing the application menu", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboards")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "they select Goal Metrics configuration", context do
        assert has_element?(context.view, "a[href='/app/correlations/goals']")
        {:ok, view, html} = live(context.owner_conn, "/app/correlations/goals")
        {:ok, Map.merge(context, %{view: view, html: html})}
      end

      then_ "they are taken to the goal metrics configuration screen", context do
        assert context.html =~ "Goal"
        {:ok, context}
      end
    end
  end
end
