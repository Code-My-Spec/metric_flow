defmodule MetricFlowSpex.Criterion791MissingSpecShowsClearErrorStateSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Missing or malformed spec shows a clear error state", criterion: 791 do
    scenario "a report whose visualization has a malformed spec shows a clear error state instead of a blank panel" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "a visualization with a malformed spec", context do
        # A nil vega_spec cannot be persisted at all -- the column has a
        # NOT NULL constraint -- so the only reachable "broken spec" state
        # is a structurally invalid map, not a missing one.
        viz =
          MetricFlowSpex.Fixtures.create_visualization_for(context.owner_email, %{
            name: "Broken Spec Report",
            vega_spec: %{"not_a_valid_vega_lite_spec" => true}
          })

        {:ok, Map.put(context, :viz_id, viz.id)}
      end

      when_ "a user views the dashboard or report containing it", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/reports/#{context.viz_id}")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "a clear error state is shown in its place rather than a blank panel", context do
        assert has_element?(context.view, "[data-role='report-spec-error']"),
               "Expected a clear error state for a malformed visualization spec"

        {:ok, context}
      end
    end
  end
end
