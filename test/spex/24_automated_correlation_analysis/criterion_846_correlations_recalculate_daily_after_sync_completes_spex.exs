defmodule MetricFlowSpex.Criterion846CorrelationsRecalculateDailyAfterSyncCompletesSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Correlations recalculate daily after sync completes", criterion: 846 do
    scenario "correlations are recalculated once a daily sync completes" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "the daily data sync has just completed", context do
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

        MetricFlowSpex.Fixtures.broadcast_sync_completed(context.owner_email, :google_ads)

        {:ok, context}
      end

      when_ "the correlation analysis job runs", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/correlations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "correlations are recalculated using the newly synced data", context do
        assert has_element?(context.view, "[data-role='last-calculated']") or
                 has_element?(context.view, "[data-role='job-running-banner']"),
               "Expected the page to reflect a fresh correlation calculation"

        {:ok, context}
      end
    end
  end
end
