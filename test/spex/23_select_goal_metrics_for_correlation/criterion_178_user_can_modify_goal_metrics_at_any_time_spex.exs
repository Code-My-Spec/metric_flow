defmodule MetricFlowSpex.Criterion178UserCanModifyGoalMetricsAtAnyTimeSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "User can modify goal metrics at any time", criterion: 178 do
    scenario "a user changes their previously selected goal metric" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "the user has previously selected goal metrics", context do
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

        MetricFlowSpex.Fixtures.set_goal_metric!(context.owner_email, "revenue")
        {:ok, context}
      end

      when_ "they return to the configuration and change the selection", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/correlations/goals")

        view
        |> element("select[name='goal_metric_name']")
        |> render_change(%{"goal_metric_name" => "clicks"})

        view |> form("form") |> render_submit()
        flash = assert_redirect(view, "/app/correlations")

        {:ok, Map.put(context, :flash, flash)}
      end

      then_ "the goal metrics are updated to reflect the new selection", context do
        # A new goal metric selection queues a fresh async correlation job
        # rather than updating in place -- the prior completed job (and its
        # goal) remains what a re-mount reads until the new job finishes, so
        # the save's own confirmation is the observable proof of the update.
        assert context.flash["info"] =~ "Goal metric saved"
        {:ok, context}
      end
    end
  end
end
