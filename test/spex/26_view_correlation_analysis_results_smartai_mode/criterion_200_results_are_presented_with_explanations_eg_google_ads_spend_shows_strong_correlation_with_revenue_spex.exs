defmodule MetricFlowSpex.Criterion200ResultsPresentedWithExplanationsSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Results are presented with explanations (e.g., Google Ads spend shows strong correlation with revenue at 7-day lag)",
    criterion: 200 do
    scenario "a strong correlation at a 7-day lag is shown with a plain-language explanation" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "a strong correlation between Google Ads spend and revenue at a 7-day lag", context do
        MetricFlowSpex.Fixtures.create_correlation_result!(context.owner_email, %{
          metric_name: "ad_spend",
          goal_metric_name: "revenue",
          coefficient: 0.82,
          optimal_lag: 7,
          provider: :google_ads
        })

        {:ok, view, _html} = live(context.owner_conn, "/app/correlations")

        view
        |> element("[data-role='mode-smart']")
        |> render_click()

        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user views the result in Smart mode", context do
        {:ok, context}
      end

      then_ "it is presented with an explanation describing the relationship and the 7-day lag in plain language", context do
        row_html =
          context.view
          |> element("[data-role='correlation-row'][data-metric='ad_spend']")
          |> render()

        assert row_html =~ "7-day" or row_html =~ "7 day",
               "Expected a plain-language explanation naming the 7-day lag, got: #{row_html}"

        assert row_html =~ "strong" or row_html =~ "Strong",
               "Expected the explanation to describe the strength of the correlation, got: #{row_html}"

        {:ok, context}
      end
    end
  end
end
