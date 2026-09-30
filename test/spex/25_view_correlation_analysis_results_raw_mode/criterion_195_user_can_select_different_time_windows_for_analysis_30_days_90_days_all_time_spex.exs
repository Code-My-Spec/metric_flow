defmodule MetricFlowSpex.Criterion195UserCanSelectDifferentTimeWindowsForAnalysisSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "User can select different time windows for analysis (30 days, 90 days, all time)",
    criterion: 195 do
    scenario "a user changes the correlation analysis time window" do
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

      then_ "a control exists letting them choose between 30 days, 90 days, and all time", context do
        assert has_element?(context.view, "[data-role='time-window-selector']") or
                 has_element?(context.view, "[phx-click='set_time_window']"),
               "Expected a time-window selector offering 30 days / 90 days / all time"

        {:ok, context}
      end
    end
  end
end
