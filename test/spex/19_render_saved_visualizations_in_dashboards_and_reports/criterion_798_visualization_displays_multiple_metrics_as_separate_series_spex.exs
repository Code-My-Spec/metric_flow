defmodule MetricFlowSpex.Criterion798VisualizationDisplaysMultipleMetricsAsSeparateSeriesSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Visualization displays multiple metrics as separate series", criterion: 798 do
    scenario "a visualization bound to two metrics renders both as separate series on the same chart" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription
      given_ :owner_has_metrics

      given_ "a visualization bound to two metrics", context do
        {:ok, new_view, _html} = live(context.owner_conn, "/app/visualizations/new")

        new_view
        |> element("[phx-value-metric='impressions']")
        |> render_click()

        new_view
        |> element("[phx-value-metric='clicks']")
        |> render_click()

        new_view
        |> element("form[phx-change='validate_name']")
        |> render_change(%{"name" => "Two Metric Series"})

        new_view
        |> element("[data-role='save-visualization-btn']")
        |> render_click()

        {:ok, index_view, _html} = live(context.owner_conn, "/app/visualizations")
        html = render(index_view)
        [_, viz_id] = Regex.run(~r/data-visualization-id="(\d+)"/, html)

        {:ok, Map.put(context, :viz_id, viz_id)}
      end

      when_ "it is rendered", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/reports/#{context.viz_id}")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "both metrics are displayed as separate series on the same chart", context do
        chart_html =
          context.view
          |> element("[data-role='vega-lite-chart']")
          |> render()

        assert chart_html =~ "layer"
        assert chart_html =~ "&quot;values&quot;",
               "Expected each layer's series data to be populated at render time, got: #{chart_html}"

        {:ok, context}
      end
    end
  end
end
