defmodule MetricFlowSpex.Criterion4083AddVisualizationsSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "User can add visualizations by selecting metrics and chart types" do
    scenario "user adds a visualization via the metric picker" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription
      given_ :owner_has_metrics

      given_ "user is on the new dashboard page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboards/new")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "user opens the metric picker and selects a metric", context do
        context.view
        |> element("[data-role='add-visualization-btn']")
        |> render_click()

        context.view
        |> element("[phx-value-metric='impressions']")
        |> render_click()

        context.view
        |> element("[data-role='confirm-add-btn']")
        |> render_click()

        {:ok, context}
      end

      then_ "a visualization card appears on the canvas", context do
        html = render(context.view)
        assert has_element?(context.view, "[data-role='visualization-card']")
        assert html =~ "impressions"
        :ok
      end
    end
  end
end
