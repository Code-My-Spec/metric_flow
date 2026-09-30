defmodule MetricFlowSpex.Criterion873ChartDisplaysAnAiInfoButtonSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Chart displays an AI info button", criterion: 873 do
    scenario "a user viewing a chart or visualization sees an AI info button once it renders" do
      given_ :owner_with_integrations

      given_ "a user viewing a chart or visualization", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the chart renders", context do
        {:ok, context}
      end

      then_ "it displays an AI info button", context do
        assert has_element?(context.view, "[data-role='ai-info-button']"),
               "Expected the rendered chart to display an AI info button"

        {:ok, context}
      end
    end
  end
end
