defmodule MetricFlowSpex.Criterion850MetricWithInsufficientHistoryIsExcludedFromCorrelationSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Metric with insufficient history is excluded from correlation", criterion: 850 do
    scenario "a metric with fewer than 30 days of data does not appear in correlation results" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "a metric with fewer than 30 days of data", context do
        yesterday = Date.add(Date.utc_today(), -1)

        Enum.each(1..35, fn i ->
          dt = DateTime.new!(Date.add(yesterday, -i), ~T[00:00:00], "Etc/UTC")

          MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{
            metric_name: "revenue",
            provider: :quickbooks,
            value: 1000.0 + i,
            recorded_at: dt
          })
        end)

        Enum.each(1..5, fn i ->
          dt = DateTime.new!(Date.add(yesterday, -i), ~T[00:00:00], "Etc/UTC")

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

        goals_view |> form("#goal-metric-form") |> render_submit()
        assert_redirect(goals_view, "/app/correlations")

        {:ok, context}
      end

      when_ "correlation analysis runs", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/correlations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "that metric is excluded from correlation calculations rather than producing an unreliable result", context do
        refute has_element?(context.view, "[data-role='correlation-row'][data-metric='clicks']"),
               "Expected the metric with only 5 days of data to be excluded from correlation results"

        {:ok, context}
      end
    end
  end
end
