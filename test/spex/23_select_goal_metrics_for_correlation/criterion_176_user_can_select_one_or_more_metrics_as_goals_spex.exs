defmodule MetricFlowSpex.Criterion176UserCanSelectOneOrMoreMetricsAsGoalsSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "User can select one or more metrics as goals", criterion: 176 do
    scenario "a user selects a single metric as a goal" do
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

      when_ "they select a metric such as their QuickBooks revenue account as a goal", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/correlations/goals")

        view
        |> element("select[name='goal_metric_name']")
        |> render_change(%{"goal_metric_name" => "revenue"})

        view |> form("#goal-metric-form") |> render_submit()
        flash = assert_redirect(view, "/app/correlations")

        {:ok, Map.put(context, :flash, flash)}
      end

      then_ "it is saved as a goal metric", context do
        assert context.flash["info"] =~ "Goal metric saved"
        {:ok, context}
      end
    end

    scenario "a user attempts to select multiple metrics as goals" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "the user has multiple available metrics", context do
        MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{metric_name: "revenue"})
        MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{metric_name: "clicks"})

        {:ok, view, _html} = live(context.owner_conn, "/app/correlations/goals")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "they attempt to select more than one metric as goals", context do
        {:ok, context}
      end

      then_ "all selected metrics are saved as goal metrics", context do
        # Real gap: the goal metric form is a single <select> dropdown, and
        # CorrelationJob.goal_metric_name is a single string field -- there is
        # no way to select or persist more than one goal metric at a time.
        assert has_element?(context.view, "input[type='checkbox'][name='goal_metric_names[]']") or
                 has_element?(context.view, "select[multiple]"),
               "Expected a way to select multiple goal metrics simultaneously"

        {:ok, context}
      end
    end
  end
end
