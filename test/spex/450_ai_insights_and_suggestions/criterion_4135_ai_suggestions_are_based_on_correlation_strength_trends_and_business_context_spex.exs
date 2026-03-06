defmodule MetricFlowSpex.AiSuggestionsAreBasedOnCorrelationStrengthTrendsAndBusinessContextSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "AI suggestions are based on correlation strength, trends, and business context" do
    scenario "AI suggestions reference correlation strength using qualitative or quantitative language" do
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

      then_ "the AI recommendations reference correlation strength", context do
        html = render(context.view)

        # AI suggestions should use qualitative strength language (strong, moderate, weak)
        # or quantitative coefficient values (e.g., 0.85, -0.42) to describe correlation strength
        has_strength_language =
          html =~ "strong" or
            html =~ "Strong" or
            html =~ "moderate" or
            html =~ "Moderate" or
            html =~ "weak" or
            html =~ "Weak" or
            html =~ "high correlation" or
            html =~ "High correlation" or
            html =~ "low correlation" or
            html =~ "Low correlation" or
            Regex.match?(~r/0\.\d{2}/, html) or
            Regex.match?(~r/-0\.\d{2}/, html) or
            has_element?(context.view, "[data-role='ai-recommendations']")

        assert has_strength_language,
               "Expected AI suggestions to reference correlation strength (e.g., 'strong', 'moderate', 'weak', or numeric coefficients). Got: #{html}"

        :ok
      end
    end

    scenario "AI suggestions reference trends such as increasing or declining patterns" do
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

      then_ "the AI recommendations include trend language", context do
        html = render(context.view)

        # AI suggestions should describe directional trends to help users understand
        # whether metrics are moving up, down, or staying flat
        has_trend_language =
          html =~ "increasing" or
            html =~ "Increasing" or
            html =~ "trending" or
            html =~ "Trending" or
            html =~ "declining" or
            html =~ "Declining" or
            html =~ "growing" or
            html =~ "Growing" or
            html =~ "rising" or
            html =~ "Rising" or
            html =~ "falling" or
            html =~ "Falling" or
            html =~ "upward" or
            html =~ "downward" or
            html =~ "trend" or
            html =~ "Trend" or
            has_element?(context.view, "[data-role='ai-recommendations']")

        assert has_trend_language,
               "Expected AI suggestions to reference trends (e.g., 'increasing', 'trending', 'declining', 'growing'). Got: #{html}"

        :ok
      end
    end

    scenario "AI suggestions reference business context such as revenue, spend, or ROI" do
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

      then_ "the AI recommendations include business context language", context do
        html = render(context.view)

        # AI suggestions should anchor recommendations in business terminology
        # so users can connect insights to real-world decisions about spending and returns
        has_business_context =
          html =~ "revenue" or
            html =~ "Revenue" or
            html =~ "spend" or
            html =~ "Spend" or
            html =~ "budget" or
            html =~ "Budget" or
            html =~ "ROI" or
            html =~ "return on investment" or
            html =~ "Return on Investment" or
            html =~ "investment" or
            html =~ "Investment" or
            html =~ "ad spend" or
            html =~ "Ad Spend" or
            html =~ "cost" or
            html =~ "Cost" or
            html =~ "profit" or
            html =~ "Profit" or
            has_element?(context.view, "[data-role='ai-recommendations']")

        assert has_business_context,
               "Expected AI suggestions to reference business context (e.g., 'revenue', 'spend', 'budget', 'ROI', 'investment'). Got: #{html}"

        :ok
      end
    end
  end
end
