defmodule MetricFlowSpex.Criterion792BoundToDeletedMetricsShowsClearErrorStateSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Visualization bound to deleted metrics shows a clear error state", criterion: 792 do
    scenario "a user views a dashboard or report whose visualization is bound to a metric that no longer exists" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "a visualization bound to a metric that no longer has any data", context do
        viz =
          MetricFlowSpex.Fixtures.create_visualization_for(context.owner_email, %{
            name: "Orphaned Metric Report",
            vega_spec: %{
              "$schema" => "https://vega.github.io/schema/vega-lite/v5.json",
              "data" => %{"name" => "discontinued_metric"},
              "mark" => "line",
              "encoding" => %{
                "x" => %{"field" => "date", "type" => "temporal"},
                "y" => %{"field" => "value", "type" => "quantitative"}
              }
            },
            metric_names: ["discontinued_metric"]
          })

        {:ok, Map.put(context, :viz_id, viz.id)}
      end

      when_ "a user views the dashboard or report containing it", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/reports/#{context.viz_id}")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "a clear error state is shown rather than a blank panel or a crash", context do
        assert has_element?(context.view, "[data-role='metric-unavailable-error']"),
               "Expected a clear error state for a visualization bound to a metric with no data"

        {:ok, context}
      end
    end
  end
end
