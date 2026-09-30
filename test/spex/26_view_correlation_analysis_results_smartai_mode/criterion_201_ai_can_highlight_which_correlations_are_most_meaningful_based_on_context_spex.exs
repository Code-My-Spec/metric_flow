defmodule MetricFlowSpex.Criterion201AiHighlightsMostMeaningfulCorrelationsSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "AI can highlight which correlations are most meaningful based on context", criterion: 201 do
    scenario "the AI highlights a contextually meaningful correlation among several shown" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "several correlations are shown in Smart/AI mode", context do
        MetricFlowSpex.Fixtures.create_correlation_result!(context.owner_email, %{
          metric_name: "ad_spend",
          goal_metric_name: "revenue",
          coefficient: 0.55,
          provider: :google_ads
        })

        MetricFlowSpex.Fixtures.create_correlation_result!(context.owner_email, %{
          metric_name: "page_views",
          goal_metric_name: "revenue",
          coefficient: 0.52,
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
               "Expected at least one correlation to be marked as AI-highlighted based on business context, distinct from its raw coefficient rank"

        {:ok, context}
      end
    end
  end
end
