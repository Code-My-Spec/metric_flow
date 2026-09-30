defmodule MetricFlowSpex.Criterion851CorrelationTreatsFinancialAndMarketingMetricsUniformlySpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Correlation treats financial and marketing metrics uniformly", criterion: 851 do
    scenario "both a financial metric and a marketing metric appear as correlation results" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "both financial metrics (e.g., QuickBooks revenue) and marketing metrics (e.g., ad clicks) are available",
             context do
        yesterday = Date.add(Date.utc_today(), -1)

        Enum.each(1..35, fn i ->
          dt = DateTime.new!(Date.add(yesterday, -i), ~T[00:00:00], "Etc/UTC")

          MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{
            metric_name: "revenue",
            provider: :quickbooks,
            value: 1000.0 + i,
            recorded_at: dt
          })

          MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{
            metric_name: "expenses",
            provider: :quickbooks,
            value: 300.0 + i,
            recorded_at: dt
          })

          MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{
            metric_name: "clicks",
            provider: :google_ads,
            value: 50.0 + i,
            recorded_at: dt
          })
        end)

        {:ok, goals_view, _html} = live(context.owner_conn, "/app/correlations/goals")

        goals_view
        |> element("select[name='goal_metric_name']")
        |> render_change(%{"goal_metric_name" => "revenue"})

        goals_view |> form("form") |> render_submit()
        assert_redirect(goals_view, "/app/correlations")

        {:ok, context}
      end

      when_ "correlation analysis runs", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/correlations")

        # The goal-metric save above already enqueued the CorrelationWorker
        # job -- Oban runs in :manual testing mode, so nothing executes it
        # until drained, matching the exunit precedent in correlations_test.exs.
        Oban.drain_queue(queue: :correlations)

        {:ok, Map.put(context, :view, view)}
      end

      then_ "it calculates correlations for both kinds of metrics the same way, without treating either category specially",
            context do
        assert has_element?(context.view, "[data-role='correlation-row'][data-metric='expenses']"),
               "Expected the financial metric (expenses) to appear in correlation results"

        assert has_element?(context.view, "[data-role='correlation-row'][data-metric='clicks']"),
               "Expected the marketing metric (clicks) to appear in correlation results"

        {:ok, context}
      end
    end
  end
end
