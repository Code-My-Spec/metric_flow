defmodule MetricFlowSpex.Criterion180WhenTheUserSelectsGoalMetricsTheSystemQueuesCorrelationAnalysisSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "When the user selects goal metrics, the system queues correlation analysis",
    criterion: 180 do
    scenario "saving a goal metric selection queues correlation analysis" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "the user has enough historical metric data for correlation to run", context do
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

        {:ok, context}
      end

      when_ "they select one or more goal metrics and save the selection", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/correlations/goals")

        view
        |> element("select[name='goal_metric_name']")
        |> render_change(%{"goal_metric_name" => "revenue"})

        view |> form("#goal-metric-form") |> render_submit()
        flash = assert_redirect(view, "/app/correlations")

        {:ok, Map.put(context, :flash, flash)}
      end

      then_ "the system queues correlation analysis for those goals", context do
        assert context.flash["info"] =~ "Correlation analysis started"
        {:ok, context}
      end
    end
  end
end
