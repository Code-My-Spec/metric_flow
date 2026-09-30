defmodule MetricFlowSpex.Criterion193UserCanViewBothPositiveAndNegativeCorrelationsSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "User can view both positive and negative correlations", criterion: 193 do
    scenario "a user viewing Raw mode sees both positive and negative correlations" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "a positive and a negative correlation have both been calculated", context do
        MetricFlowSpex.Fixtures.create_correlation_result!(context.owner_email, %{
          metric_name: "positive_metric",
          goal_metric_name: "revenue",
          coefficient: 0.65
        })

        MetricFlowSpex.Fixtures.create_correlation_result!(context.owner_email, %{
          metric_name: "negative_metric",
          goal_metric_name: "revenue",
          coefficient: -0.55
        })

        {:ok, view, _html} = live(context.owner_conn, "/app/correlations")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user views Raw mode", context do
        {:ok, context}
      end

      then_ "both the positive and the negative correlation are visible", context do
        assert has_element?(context.view, "[data-role='correlation-row'][data-metric='positive_metric']")
        assert has_element?(context.view, "[data-role='correlation-row'][data-metric='negative_metric']")
        {:ok, context}
      end
    end
  end
end
