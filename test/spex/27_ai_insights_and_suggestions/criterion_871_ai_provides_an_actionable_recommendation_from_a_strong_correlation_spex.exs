defmodule MetricFlowSpex.Criterion871AiProvidesAnActionableRecommendationFromAStrongCorrelationSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "AI provides an actionable recommendation from a strong correlation", criterion: 871 do
    scenario "Google Ads spend shows a 0.85 correlation with revenue and AI Suggestions analyzes it" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "Google Ads spend shows a 0.85 correlation with revenue", context do
        MetricFlowSpex.Fixtures.create_correlation_result!(context.owner_email, %{
          metric_name: "ad_spend",
          goal_metric_name: "revenue",
          coefficient: 0.85,
          provider: :google_ads
        })

        {:ok, view, _html} = live(context.owner_conn, "/app/correlations")

        view
        |> element("[data-role='mode-smart']")
        |> render_click()

        {:ok, Map.put(context, :view, view)}
      end

      when_ "AI Suggestions analyzes this correlation", context do
        context.view
        |> element("[data-role='enable-ai-suggestions']")
        |> render_click()

        {:ok, context}
      end

      then_ "it provides an actionable recommendation such as increasing Google Ads budget", context do
        html = render(context.view)

        has_actionable_recommendation =
          html =~ "increase" or html =~ "Increase" or html =~ "budget" or html =~ "Budget" or
            has_element?(context.view, "[data-role='ai-recommendations']")

        assert has_actionable_recommendation,
               "Expected an actionable recommendation such as increasing Google Ads budget, got: #{html}"

        {:ok, context}
      end
    end
  end
end
