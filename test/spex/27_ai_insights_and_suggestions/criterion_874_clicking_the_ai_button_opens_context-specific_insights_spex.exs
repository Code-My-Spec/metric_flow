defmodule MetricFlowSpex.Criterion874ClickingTheAiButtonOpensContextSpecificInsightsSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Clicking the AI button opens context-specific insights", criterion: 874 do
    scenario "a user viewing a chart with an AI info button clicks it" do
      given_ :owner_with_integrations

      given_ "a user viewing a chart with an AI info button", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        assert has_element?(view, "[data-role='ai-info-button'][phx-value-metric='All Metrics']")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "they click it", context do
        context.view
        |> element("[data-role='ai-info-button'][phx-value-metric='All Metrics']")
        |> render_click()

        {:ok, context}
      end

      then_ "they see context-specific insights or a chat about that metric", context do
        assert has_element?(context.view, "[data-role='ai-insights-panel']"),
               "Expected context-specific insights or a chat to open for that metric"

        {:ok, context}
      end
    end
  end
end
