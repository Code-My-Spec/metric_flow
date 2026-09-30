defmodule MetricFlowSpex.Criterion865BothPositiveAndNegativeCorrelationsAreVisibleSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Both positive and negative correlations are visible", criterion: 865 do
    scenario "a goal metric with both positively and negatively correlated metrics shows both in Raw mode" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "a goal metric with both positively and negatively correlated metrics", context do
        MetricFlowSpex.Fixtures.create_correlation_result!(context.owner_email, %{
          metric_name: "positive_metric",
          goal_metric_name: "revenue",
          coefficient: 0.7
        })

        MetricFlowSpex.Fixtures.create_correlation_result!(context.owner_email, %{
          metric_name: "negative_metric",
          goal_metric_name: "revenue",
          coefficient: -0.6
        })

        {:ok, view, _html} = live(context.owner_conn, "/app/correlations")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a user views Raw mode", context do
        {:ok, context}
      end

      then_ "both positive and negative correlations appear in the list", context do
        assert has_element?(context.view, "[data-role='correlation-row'][data-metric='positive_metric']")
        assert has_element?(context.view, "[data-role='correlation-row'][data-metric='negative_metric']")
        {:ok, context}
      end
    end
  end
end
