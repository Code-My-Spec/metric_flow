defmodule MetricFlowSpex.Criterion809SavedVisualizationAppearsInLibrarySpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Saved visualization appears in the visualization library", criterion: 809 do
    scenario "a user browses the visualization library from the report builder and finds the saved visualization" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription
      given_ :owner_has_metrics

      given_ "a visualization has been saved", context do
        {:ok, new_view, _html} = live(context.owner_conn, "/app/visualizations/new")

        new_view
        |> element("[phx-value-metric='impressions']")
        |> render_click()

        new_view
        |> element("form[phx-change='validate_name']")
        |> render_change(%{"name" => "Library Appearance Chart"})

        new_view
        |> element("[data-role='save-visualization-btn']")
        |> render_click()

        {:ok, context}
      end

      when_ "a user browses the visualization library from the report builder", context do
        {:ok, _report_view, _report_html} = live(context.owner_conn, "/app/reports")
        {:ok, library_view, html} = live(context.owner_conn, "/app/visualizations")
        {:ok, Map.merge(context, %{library_view: library_view, library_html: html})}
      end

      then_ "the saved visualization appears there", context do
        assert context.library_html =~ "Library Appearance Chart"
        {:ok, context}
      end
    end
  end
end
