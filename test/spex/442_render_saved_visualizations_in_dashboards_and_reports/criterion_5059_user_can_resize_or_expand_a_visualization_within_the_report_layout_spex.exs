defmodule MetricFlowSpex.Criterion5059ResizeOrExpandVisualizationSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "User can resize or expand a visualization within the report layout" do
    scenario "chart preview container is full-width and responsive" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription
      given_ :owner_has_metrics

      given_ "user has a chart rendered in the editor", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/visualizations/new")

        view
        |> element("[phx-value-metric='impressions']")
        |> render_click()

        {:ok, Map.put(context, :view, view)}
      end

      then_ "the chart container uses full-width responsive styling", context do
        chart_html =
          context.view
          |> element("[data-role='vega-lite-chart']")
          |> render()

        assert chart_html =~ "w-full"
        :ok
      end
    end
  end
end
