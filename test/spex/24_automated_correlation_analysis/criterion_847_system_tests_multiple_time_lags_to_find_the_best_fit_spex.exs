defmodule MetricFlowSpex.Criterion847SystemTestsMultipleTimeLagsToFindTheBestFitSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "System tests multiple time lags to find the best fit", criterion: 847 do
    scenario "a metric is tested for correlation across multiple time lags" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "a metric being tested for correlation with a goal metric", context do
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

      when_ "the analysis runs", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/correlations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the system tests time lags from 0 to 30 days for that metric", context do
        row_html =
          context.view
          |> element("[data-role='correlation-row'][data-metric='clicks']")
          |> render()

        assert row_html =~ "Same day" or Regex.match?(~r/\d+\s*days/, row_html),
               "Expected the correlation row to show a tested lag between 0 and 30 days"

        {:ok, context}
      end
    end
  end
end
