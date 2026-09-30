defmodule MetricFlowSpex.Criterion246SavedVisualizationsAppearInLibrarySpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Saved visualizations appear in the visualization library accessible from the report builder",
    criterion: 246 do
    scenario "a saved visualization appears when browsing the visualization library from the report builder" do
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
        |> render_change(%{"name" => "Library Entry Chart"})

        new_view
        |> element("[data-role='save-visualization-btn']")
        |> render_click()

        {:ok, context}
      end

      when_ "a user browses the visualization library from the report builder", context do
        {:ok, report_view, _html} = live(context.owner_conn, "/app/reports")

        report_view
        |> element("[data-role='manual-visualization-link'], a[href='/app/visualizations/new']", "Create a chart")
        |> has_element?()

        {:ok, library_view, html} = live(context.owner_conn, "/app/visualizations")
        {:ok, Map.merge(context, %{library_view: library_view, library_html: html})}
      end

      then_ "the saved visualization appears there", context do
        assert context.library_html =~ "Library Entry Chart"
        {:ok, context}
      end
    end
  end
end
