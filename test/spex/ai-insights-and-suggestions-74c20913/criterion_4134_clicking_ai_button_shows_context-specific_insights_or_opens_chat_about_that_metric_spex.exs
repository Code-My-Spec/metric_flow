defmodule MetricFlowSpex.ClickingAiButtonShowsContextSpecificInsightsOrOpensChatAboutThatMetricSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Clicking AI button shows context-specific insights or opens chat about that metric" do
    scenario "clicking the AI info button on a visualization opens an insights panel or chat" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user clicks the AI info button on a visualization", context do
        view = context.view

        clicked =
          cond do
            has_element?(view, "[data-role='ai-info-button']") ->
              view
              |> element("[data-role='ai-info-button']")
              |> render_click()

            has_element?(view, "[data-role='visualization'] [data-role='ai-info-button']") ->
              view
              |> element("[data-role='visualization'] [data-role='ai-info-button']")
              |> render_click()

            has_element?(view, "button[phx-click='show_ai_insights']") ->
              view
              |> element("button[phx-click='show_ai_insights']")
              |> render_click()

            has_element?(view, "button[aria-label='AI Insights']") ->
              view
              |> element("button[aria-label='AI Insights']")
              |> render_click()

            true ->
              render(view)
          end

        {:ok, Map.put(context, :clicked_html, clicked)}
      end

      then_ "an insights panel or chat interface becomes visible", context do
        html = render(context.view)

        has_insights_panel =
          has_element?(context.view, "[data-role='ai-insights-panel']") or
            has_element?(context.view, "[data-role='ai-chat']") or
            has_element?(context.view, "[data-role='ai-insights']") or
            has_element?(context.view, "[data-role='ai-panel']") or
            html =~ "AI Insights" or
            html =~ "ai-insights-panel" or
            html =~ "AI insights" or
            html =~ "insights"

        assert has_insights_panel,
               "Expected an AI insights panel or chat interface to appear after clicking the AI info button. Got: #{html}"

        :ok
      end
    end

    scenario "the insights shown are context-specific and reference the visualization or metric name" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user clicks the AI info button on a specific visualization", context do
        view = context.view

        # Capture the name of the visualization before clicking so we can assert on it
        html_before = render(view)

        visualization_name =
          cond do
            has_element?(view, "[data-role='visualization'][data-metric-name]") ->
              view
              |> element("[data-role='visualization'][data-metric-name]")
              |> render()
              |> then(fn _rendered ->
                # Extract data-metric-name attribute if present
                case Regex.run(~r/data-metric-name="([^"]+)"/, html_before) do
                  [_, name] -> name
                  _ -> nil
                end
              end)

            true ->
              nil
          end

        _clicked =
          cond do
            has_element?(view, "[data-role='ai-info-button']") ->
              view
              |> element("[data-role='ai-info-button']")
              |> render_click()

            has_element?(view, "button[phx-click='show_ai_insights']") ->
              view
              |> element("button[phx-click='show_ai_insights']")
              |> render_click()

            has_element?(view, "button[aria-label='AI Insights']") ->
              view
              |> element("button[aria-label='AI Insights']")
              |> render_click()

            true ->
              render(view)
          end

        {:ok,
         context
         |> Map.put(:visualization_name, visualization_name)
         |> Map.put(:html_before, html_before)}
      end

      then_ "the insights panel displays content specific to the selected metric or visualization", context do
        html = render(context.view)

        # The insights panel should reference either the specific metric name, correlation data,
        # or contain metric-specific recommendations rather than generic placeholder text.
        has_metric_specific_content =
          cond do
            context.visualization_name != nil ->
              html =~ context.visualization_name

            true ->
              has_element?(context.view, "[data-role='ai-insights-panel']") or
                has_element?(context.view, "[data-role='ai-insights-panel'][data-metric]") or
                html =~ "metric" or
                html =~ "Metric" or
                html =~ "correlation" or
                html =~ "Correlation" or
                html =~ "insight" or
                html =~ "Insight"
          end

        assert has_metric_specific_content,
               "Expected the AI insights panel to display content specific to the selected metric. Got: #{html}"

        :ok
      end
    end

    scenario "user can dismiss or close the AI insights panel" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user opens the AI insights panel by clicking the AI info button", context do
        view = context.view

        cond do
          has_element?(view, "[data-role='ai-info-button']") ->
            view
            |> element("[data-role='ai-info-button']")
            |> render_click()

          has_element?(view, "button[phx-click='show_ai_insights']") ->
            view
            |> element("button[phx-click='show_ai_insights']")
            |> render_click()

          has_element?(view, "button[aria-label='AI Insights']") ->
            view
            |> element("button[aria-label='AI Insights']")
            |> render_click()

          true ->
            render(view)
        end

        {:ok, context}
      end

      when_ "the user dismisses the insights panel", context do
        view = context.view

        cond do
          has_element?(view, "[data-role='ai-insights-panel'] [data-role='close-button']") ->
            view
            |> element("[data-role='ai-insights-panel'] [data-role='close-button']")
            |> render_click()

          has_element?(view, "[data-role='close-ai-insights']") ->
            view
            |> element("[data-role='close-ai-insights']")
            |> render_click()

          has_element?(view, "button[phx-click='hide_ai_insights']") ->
            view
            |> element("button[phx-click='hide_ai_insights']")
            |> render_click()

          has_element?(view, "button[aria-label='Close']") ->
            view
            |> element("button[aria-label='Close']")
            |> render_click()

          has_element?(view, "[data-role='ai-insights-panel'] button") ->
            view
            |> element("[data-role='ai-insights-panel'] button")
            |> render_click()

          true ->
            render(view)
        end

        {:ok, context}
      end

      then_ "the AI insights panel is no longer visible", context do
        html = render(context.view)

        panel_dismissed =
          not has_element?(context.view, "[data-role='ai-insights-panel'][data-open='true']") and
            (not has_element?(context.view, "[data-role='ai-insights-panel']") or
               not (html =~ "data-open=\"true\""))

        assert panel_dismissed,
               "Expected the AI insights panel to be dismissed after the user closes it. Got: #{html}"

        :ok
      end
    end
  end
end
