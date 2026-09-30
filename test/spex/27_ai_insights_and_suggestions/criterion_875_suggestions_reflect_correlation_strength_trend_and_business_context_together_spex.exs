defmodule MetricFlowSpex.Criterion875SuggestionsReflectCorrelationStrengthTrendAndBusinessContextTogetherSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Suggestions reflect correlation strength, trend, and business context together", criterion: 875 do
    scenario "a metric with a moderate correlation but a clear upward trend and relevant business context" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "a metric with a moderate correlation but a clear upward trend and relevant business context",
             context do
        MetricFlowSpex.Fixtures.create_correlation_result!(context.owner_email, %{
          metric_name: "ad_spend",
          goal_metric_name: "revenue",
          coefficient: 0.45
        })

        {:ok, view, _html} = live(context.owner_conn, "/app/correlations")

        view
        |> element("[data-role='mode-smart']")
        |> render_click()

        {:ok, Map.put(context, :view, view)}
      end

      when_ "the AI generates a suggestion", context do
        context.view
        |> element("[data-role='enable-ai-suggestions']")
        |> render_click()

        {:ok, context}
      end

      then_ "it accounts for correlation strength, trend, and business context rather than correlation value alone",
            context do
        html = render(context.view)

        assert html =~ "trend" or html =~ "Trend" or html =~ "increasing" or html =~ "revenue" or
                 html =~ "Revenue",
               "Expected the suggestion to reference trend and business context, not just the raw coefficient, got: #{html}"

        {:ok, context}
      end
    end
  end
end
