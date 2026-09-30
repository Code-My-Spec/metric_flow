defmodule MetricFlowSpex.Criterion148SpecIsTemplatePopulatedAtRenderTimeSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "The saved Vega-Lite spec is a template with no embedded data values -- data is fetched and injected at render time from the bound metrics",
    criterion: 148 do
    scenario "viewing a saved visualization as a report shows fresh data injected into its template spec" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription
      given_ :owner_has_metrics

      given_ "the user saves a visualization bound to one metric", context do
        {:ok, new_view, _html} = live(context.owner_conn, "/app/visualizations/new")

        new_view
        |> element("[phx-value-metric='impressions']")
        |> render_click()

        new_view
        |> element("form[phx-change='validate_name']")
        |> render_change(%{"name" => "Impressions Report"})

        new_view
        |> element("[data-role='save-visualization-btn']")
        |> render_click()

        {:ok, index_view, _html} = live(context.owner_conn, "/app/visualizations")
        html = render(index_view)
        [_, viz_id] = Regex.run(~r/data-visualization-id="(\d+)"/, html)

        {:ok, Map.put(context, :viz_id, viz_id)}
      end

      when_ "the user views it as a report", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/reports/#{context.viz_id}")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the rendered chart's spec contains real data values injected at render time, not the bare template", context do
        chart_html =
          context.view
          |> element("[data-role='vega-lite-chart']")
          |> render()

        assert chart_html =~ "&quot;values&quot;",
               "Expected the report's rendered spec to have fresh data injected from the bound metric, got: #{chart_html}"

        {:ok, context}
      end
    end
  end
end
