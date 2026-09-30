defmodule MetricFlowSpex.Criterion856AiHighlightsMostContextuallyMeaningfulCorrelationsSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "AI highlights the most contextually meaningful correlations", criterion: 856 do
    scenario "the AI marks a correlation as contextually meaningful independent of raw rank" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "several correlations are shown in Smart/AI mode", context do
        MetricFlowSpex.Fixtures.create_correlation_result!(context.owner_email, %{
          metric_name: "ad_spend",
          goal_metric_name: "revenue",
          coefficient: 0.5,
          provider: :google_ads
        })

        MetricFlowSpex.Fixtures.create_correlation_result!(context.owner_email, %{
          metric_name: "page_views",
          goal_metric_name: "revenue",
          coefficient: 0.48,
          provider: :google_analytics
        })

        {:ok, view, _html} = live(context.owner_conn, "/app/correlations")

        view
        |> element("[data-role='mode-smart']")
        |> render_click()

        {:ok, Map.put(context, :view, view)}
      end

      when_ "the AI evaluates their business context", context do
        {:ok, context}
      end

      then_ "it highlights which of them are most meaningful, not just which have the highest raw correlation value", context do
        assert has_element?(context.view, "[data-role='correlation-row'][data-ai-highlighted='true']"),
               "Expected the AI to mark at least one correlation as contextually meaningful, distinct from raw coefficient rank"

        {:ok, context}
      end
    end
  end
end
