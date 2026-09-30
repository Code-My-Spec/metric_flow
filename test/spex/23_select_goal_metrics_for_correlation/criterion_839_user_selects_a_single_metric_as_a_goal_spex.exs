defmodule MetricFlowSpex.Criterion839UserSelectsASingleMetricAsAGoalSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "User selects a single metric as a goal", criterion: 839 do
    scenario "a user in the goal metrics configuration screen selects their revenue account as a goal" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "a user in the goal metrics configuration screen", context do
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
        {:ok, Map.put(context, :view, view)}
      end

      when_ "they select a metric such as their QuickBooks revenue account as a goal", context do
        context.view
        |> element("select[name='goal_metric_name']")
        |> render_change(%{"goal_metric_name" => "revenue"})

        context.view |> form("form") |> render_submit()
        flash = assert_redirect(context.view, "/app/correlations")

        {:ok, Map.put(context, :flash, flash)}
      end

      then_ "it is saved as a goal metric", context do
        assert context.flash["info"] =~ "Goal metric saved"
        {:ok, context}
      end
    end
  end
end
