defmodule MetricFlowSpex.Criterion840UserSelectsMultipleMetricsAsGoalsSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "User selects multiple metrics as goals", criterion: 840 do
    scenario "a user in the goal metrics configuration screen selects more than one metric as goals" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "a user in the goal metrics configuration screen", context do
        MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{metric_name: "revenue"})
        MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{metric_name: "clicks"})

        {:ok, view, _html} = live(context.owner_conn, "/app/correlations/goals")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "they select more than one metric as goals", context do
        {:ok, context}
      end

      then_ "all selected metrics are saved as goal metrics", context do
        # Real gap: the goal metric form is a single <select> dropdown, and
        # CorrelationJob.goal_metric_name is a single string field -- there is
        # no way to select or persist more than one goal metric at a time.
        assert has_element?(context.view, "input[type='checkbox'][name='goal_metric_names[]']") or
                 has_element?(context.view, "select[multiple]"),
               "Expected a way to select multiple goal metrics simultaneously"

        {:ok, context}
      end
    end
  end
end
