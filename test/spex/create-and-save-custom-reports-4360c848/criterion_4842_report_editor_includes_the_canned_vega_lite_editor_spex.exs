defmodule MetricFlowSpex.Criterion4842ReportEditorIncludesVegaLiteEditorSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Report editor includes the Vega-Lite editor" do
    scenario "dashboard editor has chart type selector and metric picker" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "user opens the metric picker on a new dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboards/new")

        view
        |> element("[data-role='add-visualization-btn']")
        |> render_click()

        {:ok, Map.put(context, :view, view)}
      end

      then_ "a chart type selector is available in the metric picker", context do
        assert has_element?(context.view, "[data-role='chart-type-selector']")
        :ok
      end

      then_ "metric list shows available metrics for selection", context do
        assert has_element?(context.view, "[data-role='metric-list']")
        :ok
      end
    end
  end
end
