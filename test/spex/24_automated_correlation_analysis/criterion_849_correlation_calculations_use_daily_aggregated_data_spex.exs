defmodule MetricFlowSpex.Criterion849CorrelationCalculationsUseDailyAggregatedDataSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Correlation calculations use daily aggregated data", criterion: 849 do
    scenario "multiple same-day records are aggregated to a single daily data point before correlation" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "raw synced data at whatever granularity it arrives in", context do
        yesterday = Date.add(Date.utc_today(), -1)

        Enum.each(1..35, fn i ->
          date = Date.add(yesterday, -i)

          # Two records land on the same day at different times -- raw,
          # sub-daily granularity that the calculation must aggregate.
          MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{
            metric_name: "revenue",
            provider: :quickbooks,
            value: 500.0 + i,
            recorded_at: DateTime.new!(date, ~T[06:00:00], "Etc/UTC")
          })

          MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{
            metric_name: "revenue",
            provider: :quickbooks,
            value: 500.0 + i,
            recorded_at: DateTime.new!(date, ~T[18:00:00], "Etc/UTC")
          })

          MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{
            metric_name: "clicks",
            provider: :google_ads,
            value: 50.0 + i,
            recorded_at: DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
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

      when_ "correlation calculations run", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/correlations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "they operate on daily aggregated values rather than raw or differently-aggregated data", context do
        row_html =
          context.view
          |> element("[data-role='correlation-row'][data-metric='clicks']")
          |> render()

        assert row_html =~ "35 pts",
               "Expected 35 daily data points (one per day), not 70 raw records. Got: #{row_html}"

        {:ok, context}
      end
    end
  end
end
