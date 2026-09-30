defmodule MetricFlowSpex.Criterion147VisualizationsBoundViaJoinTableSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Visualizations are permanently bound to one or more metrics via a join table, not by embedding data in the spec",
    criterion: 147 do
    scenario "a saved visualization's spec references its bound metric by name, not by embedded values" do
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
        |> render_change(%{"name" => "Impressions Trend"})

        new_view
        |> element("[data-role='save-visualization-btn']")
        |> render_click()

        {:ok, index_view, _html} = live(context.owner_conn, "/app/visualizations")
        html = render(index_view)
        [_, viz_id] = Regex.run(~r/data-visualization-id="(\d+)"/, html)

        {:ok, Map.put(context, :viz_id, viz_id)}
      end

      when_ "the user reopens the visualization for editing", context do
        {:ok, edit_view, _html} =
          live(context.owner_conn, "/app/visualizations/#{context.viz_id}/edit")

        edit_view
        |> element("[data-role='open-spec-panel']")
        |> render_click()

        {:ok, Map.put(context, :edit_view, edit_view)}
      end

      then_ "the spec references the bound metric by name, with no embedded data values", context do
        spec_text =
          context.edit_view
          |> element("[data-role='vega-spec-textarea']")
          |> render()

        assert spec_text =~ "impressions"
        refute spec_text =~ "&quot;values&quot;"
        {:ok, context}
      end
    end
  end
end
