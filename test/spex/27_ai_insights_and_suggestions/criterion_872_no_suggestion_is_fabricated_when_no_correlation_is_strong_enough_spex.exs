defmodule MetricFlowSpex.Criterion872NoSuggestionIsFabricatedWhenNoCorrelationIsStrongEnoughSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "No suggestion is fabricated when no correlation is strong enough", criterion: 872 do
    scenario "none of the account's correlations are strong enough to support a confident recommendation" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "none of the account's correlations are strong enough to support a confident recommendation",
             context do
        MetricFlowSpex.Fixtures.create_correlation_result!(context.owner_email, %{
          metric_name: "weak_metric",
          goal_metric_name: "revenue",
          coefficient: 0.15
        })

        {:ok, view, _html} = live(context.owner_conn, "/app/correlations")

        view
        |> element("[data-role='mode-smart']")
        |> render_click()

        {:ok, Map.put(context, :view, view)}
      end

      when_ "AI Suggestions analyzes the data", context do
        context.view
        |> element("[data-role='enable-ai-suggestions']")
        |> render_click()

        {:ok, context}
      end

      then_ "no suggestion is presented rather than a fabricated or low-confidence recommendation", context do
        refute has_element?(context.view, "[data-role='ai-recommendations'] [data-role='correlation-row']"),
               "Expected no fabricated recommendation when no correlation is strong enough"

        {:ok, context}
      end
    end
  end
end
