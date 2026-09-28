defmodule MetricFlowSpex.Criterion5061InsertSavedVizFromLibrarySpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "User can insert a saved visualization from the library into a custom report", criterion: 160 do
    scenario "the add visualization button opens a picker with available metrics" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "user is on the new dashboard page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboards/new")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "user clicks Add Visualization", context do
        context.view
        |> element("[data-role='add-visualization-btn']")
        |> render_click()

        {:ok, context}
      end

      then_ "the metric picker panel opens", context do
        assert has_element?(context.view, "[data-role='metric-picker']")
        {:ok, context}
      end

      then_ "a confirm button allows adding the selected visualization", context do
        assert has_element?(context.view, "[data-role='confirm-add-btn']")
        {:ok, context}
      end
    end
  end
end
