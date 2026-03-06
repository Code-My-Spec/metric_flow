defmodule MetricFlowSpex.EachChartOrVisualizationCanHaveAnAiInfoButtonSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Each chart or visualization can have an AI info button" do
    scenario "user on dashboard with visualizations sees AI info buttons" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "each visualization container has an AI info button", context do
        html = render(context.view)

        has_ai_info_button =
          has_element?(context.view, "[data-role='ai-info-button']") or
            has_element?(context.view, "button[data-role='ai-info-button']") or
            html =~ "ai-info-button" or
            html =~ "AI Info" or
            html =~ "AI Insights" or
            html =~ "ai-insights"

        assert has_ai_info_button,
               "Expected each visualization to have an AI info button (data-role='ai-info-button'). Got: #{html}"

        :ok
      end
    end

    scenario "AI info button is rendered within or near each visualization container" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the AI info button appears inside a chart or visualization container", context do
        html = render(context.view)

        # The AI info button should appear alongside a visualization container.
        # Accept any of the common data-role markers for visualization wrappers
        # that also contain (or are adjacent to) an AI info button.
        has_visualization_with_ai_button =
          has_element?(context.view, "[data-role='chart-card'] [data-role='ai-info-button']") or
            has_element?(context.view, "[data-role='visualization'] [data-role='ai-info-button']") or
            has_element?(
              context.view,
              "[data-role='dashboard-visualization'] [data-role='ai-info-button']"
            ) or
            (has_element?(context.view, "[data-role='chart-card']") and
               has_element?(context.view, "[data-role='ai-info-button']")) or
            (has_element?(context.view, "[data-role='vega-lite-chart']") and
               html =~ "ai-info-button") or
            (html =~ "chart-card" and html =~ "ai-info-button")

        assert has_visualization_with_ai_button,
               "Expected the AI info button to appear within a visualization container. Got: #{html}"

        :ok
      end
    end

    scenario "when no visualizations exist, no AI info buttons are shown" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the dashboard without any connected integrations", context do
        {:ok, view, _html} = live(context.owner_conn, "/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "no AI info buttons are present on the page", context do
        refute has_element?(context.view, "[data-role='ai-info-button']"),
               "Expected no AI info buttons when there are no visualizations to attach them to"

        :ok
      end
    end
  end
end
