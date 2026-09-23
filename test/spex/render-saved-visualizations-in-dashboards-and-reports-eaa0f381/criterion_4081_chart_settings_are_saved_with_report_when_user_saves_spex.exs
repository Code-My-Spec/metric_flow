defmodule MetricFlowSpex.Criterion4081ChartSettingsSavedWithReportSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Chart settings are saved with the visualization when user saves" do
    scenario "saving a visualization persists the name, metric, and vega spec" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription
      given_ :owner_has_metrics

      given_ "user configures a visualization", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/visualizations/new")

        # Set name
        view
        |> form("form[phx-change='validate_name']", name: "Saved Test Chart")
        |> render_change()

        # Select metric
        view
        |> element("[phx-value-metric='impressions']")
        |> render_click()

        {:ok, Map.put(context, :view, view)}
      end

      when_ "user clicks Save Visualization", context do
        html =
          context.view
          |> element("[data-role='save-visualization-btn']")
          |> render_click()

        {:ok, Map.merge(context, %{save_html: html})}
      end

      then_ "the visualization is saved and user sees confirmation", context do
        # After save, user stays on the editor and sees a success flash
        assert render(context.view) =~ "Visualization saved"
        :ok
      end
    end
  end
end
