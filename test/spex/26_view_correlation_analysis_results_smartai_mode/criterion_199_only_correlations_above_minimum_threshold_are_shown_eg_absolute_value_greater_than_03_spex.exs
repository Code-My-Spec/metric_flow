defmodule MetricFlowSpex.Criterion199OnlyCorrelationsAboveMinimumThresholdAreShownSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Only correlations above minimum threshold are shown (e.g., absolute value greater than 0.3)",
    criterion: 199 do
    scenario "a correlation below the 0.3 threshold is excluded from Smart mode" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "correlations both above and below the minimum threshold", context do
        MetricFlowSpex.Fixtures.create_correlation_result!(context.owner_email, %{
          metric_name: "strong_positive",
          goal_metric_name: "revenue",
          coefficient: 0.65
        })

        MetricFlowSpex.Fixtures.create_correlation_result!(context.owner_email, %{
          metric_name: "weak_below_threshold",
          goal_metric_name: "revenue",
          coefficient: 0.15
        })

        {:ok, view, _html} = live(context.owner_conn, "/app/correlations")

        view
        |> element("[data-role='mode-smart']")
        |> render_click()

        {:ok, Map.put(context, :view, view)}
      end

      when_ "Smart mode displays results", context do
        {:ok, context}
      end

      then_ "only the correlation above the 0.3 threshold is shown", context do
        assert has_element?(context.view, "[data-role='correlation-row'][data-metric='strong_positive']")

        refute has_element?(context.view, "[data-role='correlation-row'][data-metric='weak_below_threshold']"),
               "Expected the correlation below the 0.3 threshold to be excluded from Smart mode"

        {:ok, context}
      end
    end
  end
end
