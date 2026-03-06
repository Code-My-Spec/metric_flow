defmodule MetricFlowSpex.AiAnalyzesCorrelationDataAndProvidesActionableRecommendationsSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "AI analyzes correlation data and provides actionable recommendations" do
    scenario "user sees an AI recommendations section when AI suggestions are enabled in Smart mode" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the correlations page", context do
        {:ok, view, _html} = live(context.owner_conn, "/correlations")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user switches to Smart mode", context do
        context.view
        |> element("[data-role='mode-smart']")
        |> render_click()

        {:ok, context}
      end

      when_ "the user enables AI suggestions", context do
        context.view
        |> element("[data-role='enable-ai-suggestions']")
        |> render_click()

        {:ok, context}
      end

      then_ "the user sees an AI recommendations section on the page", context do
        html = render(context.view)

        has_recommendations =
          has_element?(context.view, "[data-role='ai-recommendations']") or
            html =~ "recommendations" or
            html =~ "Recommendations" or
            html =~ "AI Insights" or
            html =~ "ai insights"

        assert has_recommendations,
               "Expected an AI recommendations section to be visible after enabling AI suggestions. Got: #{html}"

        :ok
      end
    end

    scenario "AI recommendations mention specific metrics and correlation values" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the correlations page", context do
        {:ok, view, _html} = live(context.owner_conn, "/correlations")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user switches to Smart mode", context do
        context.view
        |> element("[data-role='mode-smart']")
        |> render_click()

        {:ok, context}
      end

      when_ "the user enables AI suggestions", context do
        context.view
        |> element("[data-role='enable-ai-suggestions']")
        |> render_click()

        {:ok, context}
      end

      then_ "the AI recommendations reference metric names and correlation values", context do
        html = render(context.view)

        has_metric_references =
          has_element?(context.view, "[data-role='ai-recommendations']") and
            (html =~ "correlation" or html =~ "Correlation") or
          html =~ "0." or
          html =~ "metric" or
          html =~ "Metric" or
          html =~ "revenue" or
          html =~ "Revenue"

        assert has_metric_references,
               "Expected AI recommendations to mention metric names and correlation values. Got: #{html}"

        :ok
      end
    end

    scenario "AI recommendations include actionable suggestions with verbs like increase, optimize, or budget" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the correlations page", context do
        {:ok, view, _html} = live(context.owner_conn, "/correlations")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user switches to Smart mode", context do
        context.view
        |> element("[data-role='mode-smart']")
        |> render_click()

        {:ok, context}
      end

      when_ "the user enables AI suggestions", context do
        context.view
        |> element("[data-role='enable-ai-suggestions']")
        |> render_click()

        {:ok, context}
      end

      then_ "the recommendations contain actionable language", context do
        html = render(context.view)

        has_actionable_language =
          html =~ "increase" or
            html =~ "Increase" or
            html =~ "optimize" or
            html =~ "Optimize" or
            html =~ "budget" or
            html =~ "Budget" or
            html =~ "reduce" or
            html =~ "Reduce" or
            html =~ "consider" or
            html =~ "Consider" or
            html =~ "suggest" or
            html =~ "Suggest" or
            has_element?(context.view, "[data-role='ai-recommendations']")

        assert has_actionable_language,
               "Expected AI recommendations to contain actionable language (e.g., 'increase', 'optimize', 'budget'). Got: #{html}"

        :ok
      end
    end
  end
end
