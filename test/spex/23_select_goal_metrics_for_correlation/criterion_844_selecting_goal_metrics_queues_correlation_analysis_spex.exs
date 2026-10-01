defmodule MetricFlowSpex.Criterion844SelectingGoalMetricsQueuesCorrelationAnalysisSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Selecting goal metrics queues correlation analysis", criterion: 844 do
    scenario "saving a goal metric selection queues correlation analysis for those goals" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "a user selects one or more goal metrics", context do
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

        {:ok, view, _html} = live(context.owner_conn, "/app/correlations/goals")

        view
        |> element("select[name='goal_metric_name']")
        |> render_change(%{"goal_metric_name" => "revenue"})

        {:ok, Map.put(context, :view, view)}
      end

      when_ "the selection is saved", context do
        context.view |> form("#goal-metric-form") |> render_submit()
        flash = assert_redirect(context.view, "/app/correlations")
        {:ok, Map.put(context, :flash, flash)}
      end

      then_ "the system queues correlation analysis for those goals", context do
        assert context.flash["info"] =~ "Correlation analysis started"
        {:ok, context}
      end
    end
  end
end
