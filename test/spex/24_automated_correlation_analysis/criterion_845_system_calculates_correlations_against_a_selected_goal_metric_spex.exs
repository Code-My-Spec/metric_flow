defmodule MetricFlowSpex.Criterion845SystemCalculatesCorrelationsAgainstASelectedGoalMetricSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "System calculates correlations against a selected goal metric", criterion: 845 do
    scenario "a user with a selected goal metric triggers correlation analysis" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "a user has selected a goal metric", context do
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

        goals_view |> form("form") |> render_submit()
        assert_redirect(goals_view, "/app/correlations")

        {:ok, context}
      end

      when_ "correlation analysis runs", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/correlations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the system calculates a correlation between that goal metric and every other available metric", context do
        assert has_element?(context.view, "[data-role='correlation-row'][data-metric='clicks']"),
               "Expected a correlation result between the goal metric and clicks"

        {:ok, context}
      end
    end
  end
end
