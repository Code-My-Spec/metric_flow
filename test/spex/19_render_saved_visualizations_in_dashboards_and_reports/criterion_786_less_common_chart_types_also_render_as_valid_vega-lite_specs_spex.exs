defmodule MetricFlowSpex.Criterion786LessCommonChartTypesRenderAsValidSpecsSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Less common chart types also render as valid Vega-Lite specs", criterion: 786 do
    scenario "a visualization configured as a donut or Gantt chart renders correctly" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription
      given_ :owner_has_metrics

      given_ "a visualization with a bound metric", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/visualizations/new")

        view
        |> element("[phx-value-metric='impressions']")
        |> render_click()

        {:ok, Map.put(context, :view, view)}
      end

      then_ "each of donut and Gantt renders as a valid Vega-Lite specification", context do
        for chart_type <- ["donut", "gantt"] do
          assert has_element?(context.view, "[phx-value-chart_type='#{chart_type}']"),
                 "Expected a #{chart_type} chart type option to exist"

          context.view
          |> element("[phx-value-chart_type='#{chart_type}']")
          |> render_click()

          chart_html =
            context.view
            |> element("[data-role='vega-lite-chart']")
            |> render()

          assert chart_html =~ "data-spec="
        end

        {:ok, context}
      end
    end
  end
end
