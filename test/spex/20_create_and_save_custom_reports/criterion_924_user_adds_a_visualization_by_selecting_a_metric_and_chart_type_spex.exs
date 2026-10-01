defmodule MetricFlowSpex.UserAddsAVisualizationBySelectingAMetricAndChartTypeSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "User adds a visualization by selecting a metric and chart type", criterion: 924 do
    scenario "selecting a metric and chart type adds a visualization to the report" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "a user editing a report", context do
        dt = DateTime.new!(Date.add(Date.utc_today(), -1), ~T[00:00:00], "Etc/UTC")

        MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{
          metric_name: "Clicks",
          provider: :google_ads,
          value: 10.0,
          recorded_at: dt
        })

        {:ok, view, _html} = live(context.owner_conn, "/app/dashboards/new")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "they add a visualization by selecting a metric and a chart type", context do
        context.view
        |> element("[data-role='add-visualization-btn']")
        |> render_click()

        context.view
        |> element("[phx-click='select_metric'][phx-value-metric='clicks']")
        |> render_click()

        context.view
        |> element("[phx-click='select_chart_type'][phx-value-chart_type='bar']")
        |> render_click()

        context.view
        |> element("[data-role='confirm-add-btn']")
        |> render_click()

        {:ok, context}
      end

      then_ "that visualization is added to the report", context do
        html = render(context.view)
        assert has_element?(context.view, "[data-role='visualization-card']")
        assert html =~ "clicks"
        {:ok, context}
      end
    end
  end
end
