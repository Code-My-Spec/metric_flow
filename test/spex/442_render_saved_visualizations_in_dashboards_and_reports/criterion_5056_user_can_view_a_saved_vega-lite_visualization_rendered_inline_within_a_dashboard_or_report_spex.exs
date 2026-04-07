defmodule MetricFlowSpex.Criterion5056SavedVizRenderedInlineDashboardSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "User can view a saved Vega-Lite visualization rendered inline within a dashboard" do
    scenario "saved visualization appears on the dashboard with VegaLite rendering" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription
      given_ :owner_has_metrics

      given_ "user creates and saves a visualization", context do
        {:ok, view, _html} = live(context.owner_conn, "/visualizations/new")

        # Set name
        view
        |> form("form[phx-change='validate_name']", name: "Inline Viz Test")
        |> render_change()

        # Select metric
        view
        |> element("[phx-value-metric='impressions']")
        |> render_click()

        # Save
        view
        |> element("[data-role='save-visualization-btn']")
        |> render_click()

        {:ok, context}
      end

      when_ "user navigates to the visualizations list", context do
        {:ok, view, html} = live(context.owner_conn, "/visualizations")
        {:ok, Map.merge(context, %{view: view, html: html})}
      end

      then_ "the saved visualization appears in the list", context do
        assert context.html =~ "Inline Viz Test"
        :ok
      end
    end
  end
end
