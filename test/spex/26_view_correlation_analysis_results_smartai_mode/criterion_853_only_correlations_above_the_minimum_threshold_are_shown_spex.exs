defmodule MetricFlowSpex.Criterion853OnlyCorrelationsAboveTheMinimumThresholdAreShownSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Only correlations above the minimum threshold are shown", criterion: 853 do
    scenario "correlations of varying strength are filtered to only those above 0.3" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "calculated correlations of varying strength", context do
        MetricFlowSpex.Fixtures.create_correlation_result!(context.owner_email, %{
          metric_name: "above_threshold",
          goal_metric_name: "revenue",
          coefficient: 0.45
        })

        MetricFlowSpex.Fixtures.create_correlation_result!(context.owner_email, %{
          metric_name: "below_threshold",
          goal_metric_name: "revenue",
          coefficient: 0.12
        })

        {:ok, view, _html} = live(context.owner_conn, "/app/correlations")

        view
        |> element("[data-role='mode-smart']")
        |> render_click()

        {:ok, Map.put(context, :view, view)}
      end

      when_ "Smart/AI mode displays results", context do
        {:ok, context}
      end

      then_ "only correlations with an absolute value greater than 0.3 are included", context do
        assert has_element?(context.view, "[data-role='correlation-row'][data-metric='above_threshold']")

        refute has_element?(context.view, "[data-role='correlation-row'][data-metric='below_threshold']"),
               "Expected the correlation with |coefficient| <= 0.3 to be excluded"

        {:ok, context}
      end
    end
  end
end
