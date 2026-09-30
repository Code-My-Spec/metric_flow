defmodule MetricFlowSpex.Criterion785CommonChartTypesRenderAsValidSpecsSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Common chart types render as valid Vega-Lite specs", criterion: 785 do
    scenario "a visualization configured as a line, bar, area, or scatter chart renders correctly" do
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

      then_ "each of line, bar, area, and scatter renders as a valid Vega-Lite specification", context do
        for chart_type <- ["line", "bar", "area", "scatter"] do
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
