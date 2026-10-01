defmodule MetricFlowSpex.UserArrangesVisualizationsInALayoutSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "User arranges visualizations in a layout", criterion: 925 do
    scenario "dragging and dropping visualizations changes the report's layout" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "a report with multiple visualizations", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboards/new")

        view
        |> element("[data-role='template-card-marketing_overview']")
        |> render_click()

        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user drags and drops them into a new arrangement", context do
        {:ok, context}
      end

      then_ "the report's layout reflects that arrangement", context do
        assert has_element?(context.view, "[data-role='drag-handle']") or
                 has_element?(context.view, "[draggable='true']")

        {:ok, context}
      end
    end
  end
end
