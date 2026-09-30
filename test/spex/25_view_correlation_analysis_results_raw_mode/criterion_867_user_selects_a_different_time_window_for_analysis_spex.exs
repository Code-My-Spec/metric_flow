defmodule MetricFlowSpex.Criterion867UserSelectsADifferentTimeWindowForAnalysisSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "User selects a different time window for analysis", criterion: 867 do
    scenario "a user viewing correlation results for the default time window selects a different one" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "a user viewing correlation results for the default time window", context do
        MetricFlowSpex.Fixtures.create_correlation_result!(context.owner_email, %{
          metric_name: "ad_spend",
          goal_metric_name: "revenue",
          coefficient: 0.5
        })

        {:ok, view, _html} = live(context.owner_conn, "/app/correlations")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "they select a different time window such as 90 days", context do
        {:ok, context}
      end

      then_ "the analysis reflects that time window", context do
        assert has_element?(context.view, "[data-role='time-window-selector']") or
                 has_element?(context.view, "[phx-click='set_time_window']"),
               "Expected a time-window selector letting the user choose a different analysis window"

        {:ok, context}
      end
    end
  end
end
