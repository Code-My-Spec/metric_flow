defmodule MetricFlowSpex.Criterion852SmartModeShowsTop5PositiveAndNegativeCorrelationsSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Smart mode shows top 5 positive and top 5 negative correlations", criterion: 852 do
    scenario "a goal metric with many calculated correlations shows only the top 5 of each sign" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "a goal metric with many calculated correlations", context do
        for i <- 1..7 do
          MetricFlowSpex.Fixtures.create_correlation_result!(context.owner_email, %{
            metric_name: "positive_metric_#{i}",
            goal_metric_name: "revenue",
            coefficient: 0.4 + i / 100,
            provider: :google_ads
          })

          MetricFlowSpex.Fixtures.create_correlation_result!(context.owner_email, %{
            metric_name: "negative_metric_#{i}",
            goal_metric_name: "revenue",
            coefficient: -(0.4 + i / 100),
            provider: :google_analytics
          })
        end

        {:ok, view, _html} = live(context.owner_conn, "/app/correlations")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a user views Smart/AI mode", context do
        context.view
        |> element("[data-role='mode-smart']")
        |> render_click()

        {:ok, context}
      end

      then_ "they see the top 5 positive and top 5 negative correlations", context do
        html = render(context.view)
        parsed = Floki.parse_document!(html)

        positive_count =
          parsed
          |> Floki.find("[data-role='top-positive-correlations'] [data-role='correlation-row']")
          |> length()

        negative_count =
          parsed
          |> Floki.find("[data-role='top-negative-correlations'] [data-role='correlation-row']")
          |> length()

        assert positive_count == 5, "Expected exactly 5 positive correlations, got #{positive_count}"
        assert negative_count == 5, "Expected exactly 5 negative correlations, got #{negative_count}"

        {:ok, context}
      end
    end
  end
end
