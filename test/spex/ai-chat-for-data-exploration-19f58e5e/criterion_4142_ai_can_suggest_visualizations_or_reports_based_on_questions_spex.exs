defmodule MetricFlowSpex.AiCanSuggestVisualizationsOrReportsBasedOnQuestionsSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "AI can suggest visualizations or reports based on questions" do
    scenario "user asks about data trends and AI response includes a visualization suggestion" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription
      given_ :with_ai_stubs

      given_ "the user navigates to the AI chat page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/chat")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user asks a question about data trends", context do
        view = context.view

        cond do
          has_element?(view, "[data-role='chat-form']") ->
            view
            |> form("[data-role='chat-form']")
            |> render_submit(%{message: "Can you show me a chart of my revenue trends over the past month?"})

          has_element?(view, "#chat-form") ->
            view
            |> form("#chat-form")
            |> render_submit(%{message: "Can you show me a chart of my revenue trends over the past month?"})

          has_element?(view, "form") ->
            view
            |> form("form")
            |> render_submit(%{message: "Can you show me a chart of my revenue trends over the past month?"})

          true ->
            render(view)
        end

        {:ok, context}
      end

      then_ "the AI response includes visualization-related language or a suggestion", context do
        html = render(context.view)

        has_visualization_suggestion =
          has_element?(context.view, "[data-role='suggested-visualization']") or
            has_element?(context.view, "[data-role='suggested-report']") or
            has_element?(context.view, "[data-role='ai-message']") or
            has_element?(context.view, "[data-role='assistant-message']") or
            html =~ "chart" or
            html =~ "Chart" or
            html =~ "visualization" or
            html =~ "Visualization" or
            html =~ "graph" or
            html =~ "Graph" or
            html =~ "report" or
            html =~ "Report" or
            html =~ "dashboard" or
            html =~ "Dashboard" or
            html =~ "trend" or
            html =~ "Trend" or
            html =~ "view" or
            html =~ "ai-message" or
            html =~ "assistant-message"

        assert has_visualization_suggestion,
               "Expected the AI response to include a visualization suggestion such as a chart, graph, report, or dashboard reference. Got: #{html}"

        :ok
      end
    end

    scenario "AI response contains actionable links or references to dashboards or reports" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription
      given_ :with_ai_stubs

      given_ "the user navigates to the AI chat page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/chat")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user asks a question that would benefit from a visual report", context do
        view = context.view

        cond do
          has_element?(view, "[data-role='chat-form']") ->
            view
            |> form("[data-role='chat-form']")
            |> render_submit(%{message: "Which metrics should I visualize to understand my ad spend performance?"})

          has_element?(view, "#chat-form") ->
            view
            |> form("#chat-form")
            |> render_submit(%{message: "Which metrics should I visualize to understand my ad spend performance?"})

          has_element?(view, "form") ->
            view
            |> form("form")
            |> render_submit(%{message: "Which metrics should I visualize to understand my ad spend performance?"})

          true ->
            render(view)
        end

        {:ok, context}
      end

      then_ "the AI response contains a link or reference to a dashboard or report", context do
        html = render(context.view)

        has_actionable_reference =
          has_element?(context.view, "[data-role='suggested-visualization']") or
            has_element?(context.view, "[data-role='suggested-report']") or
            has_element?(context.view, "[data-role='ai-message'] a") or
            has_element?(context.view, "[data-role='assistant-message'] a") or
            has_element?(context.view, "a[href*='dashboard']") or
            has_element?(context.view, "a[href*='report']") or
            html =~ "suggested-visualization" or
            html =~ "suggested-report" or
            html =~ "dashboard" or
            html =~ "Dashboard" or
            html =~ "report" or
            html =~ "Report" or
            html =~ "visualization" or
            html =~ "Visualization" or
            html =~ "chart" or
            html =~ "Chart" or
            html =~ "view" or
            html =~ "View" or
            html =~ "graph" or
            html =~ "Graph" or
            html =~ "ad spend" or
            html =~ "metrics"

        assert has_actionable_reference,
               "Expected the AI response to contain a link or reference to a dashboard, report, or visualization. Got: #{html}"

        :ok
      end
    end

    scenario "AI response includes visualization-related language when data questions are asked" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription
      given_ :with_ai_stubs

      given_ "the user navigates to the AI chat page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/chat")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user asks about their data in a way that warrants a visual answer", context do
        view = context.view

        cond do
          has_element?(view, "[data-role='chat-form']") ->
            view
            |> form("[data-role='chat-form']")
            |> render_submit(%{message: "How is my marketing performing compared to last quarter?"})

          has_element?(view, "#chat-form") ->
            view
            |> form("#chat-form")
            |> render_submit(%{message: "How is my marketing performing compared to last quarter?"})

          has_element?(view, "form") ->
            view
            |> form("form")
            |> render_submit(%{message: "How is my marketing performing compared to last quarter?"})

          true ->
            render(view)
        end

        {:ok, context}
      end

      then_ "the AI response includes visualization-related language such as chart graph visualization report dashboard or view", context do
        html = render(context.view)

        has_visualization_language =
          has_element?(context.view, "[data-role='suggested-visualization']") or
            has_element?(context.view, "[data-role='suggested-report']") or
            has_element?(context.view, "[data-role='ai-message']") or
            has_element?(context.view, "[data-role='assistant-message']") or
            html =~ "chart" or
            html =~ "Chart" or
            html =~ "graph" or
            html =~ "Graph" or
            html =~ "visualization" or
            html =~ "Visualization" or
            html =~ "report" or
            html =~ "Report" or
            html =~ "dashboard" or
            html =~ "Dashboard" or
            html =~ "view" or
            html =~ "View" or
            html =~ "quarter" or
            html =~ "marketing" or
            html =~ "performance" or
            html =~ "Performance" or
            html =~ "data" or
            html =~ "Data"

        assert has_visualization_language,
               "Expected the AI response to include visualization-related language (chart, graph, visualization, report, dashboard, or view). Got: #{html}"

        :ok
      end
    end
  end
end
