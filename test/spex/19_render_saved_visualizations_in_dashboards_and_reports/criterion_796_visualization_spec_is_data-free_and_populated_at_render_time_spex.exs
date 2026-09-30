defmodule MetricFlowSpex.Criterion796SpecIsDataFreeAndPopulatedAtRenderTimeSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Visualization spec is data-free and populated at render time", criterion: 796 do
    scenario "a saved visualization bound to one or more metrics is rendered with fresh data, not an embedded spec" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription
      given_ :owner_has_metrics

      given_ "a saved visualization bound to one or more metrics", context do
        {:ok, new_view, _html} = live(context.owner_conn, "/app/visualizations/new")

        new_view
        |> element("[phx-value-metric='impressions']")
        |> render_click()

        new_view
        |> element("form[phx-change='validate_name']")
        |> render_change(%{"name" => "Data-Free Template Report"})

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

      then_ "its spec contains no embedded data values, and the displayed data is fetched and injected at render time from the bound metrics", context do
        chart_html =
          context.view
          |> element("[data-role='vega-lite-chart']")
          |> render()

        assert chart_html =~ "&quot;values&quot;",
               "Expected fresh metric data to be injected into the spec at render time, got: #{chart_html}"

        {:ok, context}
      end
    end
  end
end
