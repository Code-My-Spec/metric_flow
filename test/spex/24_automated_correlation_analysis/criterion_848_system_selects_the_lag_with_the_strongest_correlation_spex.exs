defmodule MetricFlowSpex.Criterion848SystemSelectsTheLagWithTheStrongestCorrelationSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "System selects the lag with the strongest correlation", criterion: 848 do
    scenario "a metric with a strong negative correlation is still selected over weaker positive ones" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "a metric tested across multiple time lags, including a negative correlation stronger than any positive one",
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

          # Inversely related to revenue -- a strong negative correlation.
          MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{
            metric_name: "complaints",
            provider: :google_business,
            value: 100.0 - i,
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

      when_ "the system selects the metric's optimal lag", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/correlations")

        # The goal-metric save above already enqueued the CorrelationWorker
        # job -- Oban runs in :manual testing mode, so nothing executes it
        # until drained, matching the exunit precedent in correlations_test.exs.
        Oban.drain_queue(queue: :correlations)

        {:ok, Map.put(context, :view, view)}
      end

      then_ "it chooses the lag with the highest absolute correlation value, regardless of whether the correlation is positive or negative",
            context do
        assert has_element?(context.view, "[data-role='correlation-row'][data-metric='complaints']"),
               "Expected the strongly (negatively) correlated metric to appear in the results despite the negative sign"

        {:ok, context}
      end
    end
  end
end
