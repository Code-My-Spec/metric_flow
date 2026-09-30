defmodule MetricFlowSpex.Criterion787ChartsRespondToHoverAndClickInteractionsSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Charts respond to hover and click interactions", criterion: 787 do
    scenario "a rendered chart supports hover for details and click to drill down" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription
      given_ :owner_has_metrics

      given_ "a rendered chart", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/visualizations/new")

        view
        |> element("[phx-value-metric='impressions']")
        |> render_click()

        {:ok, Map.put(context, :view, view)}
      end

      then_ "hovering over a data point shows details, and clicking it drills down where supported", context do
        assert has_element?(context.view, "[phx-hook='VegaLite'][data-role='vega-lite-chart']"),
               "Expected the chart to be wired for client-side interactivity (hover details)"

        assert has_element?(context.view, "[data-role='chart-drilldown']"),
               "Expected a click-to-drill-down affordance on the rendered chart"

        {:ok, context}
      end
    end
  end
end
