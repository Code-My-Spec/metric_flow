defmodule MetricFlowSpex.UserInsertsASavedVisualizationFromTheLibraryIntoAReportSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "User inserts a saved visualization from the library into a report", criterion: 933 do
    scenario "inserting a library visualization renders it inline in the report" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "a user editing a custom report and a saved visualization in the visualization library",
             context do
        visualization =
          MetricFlowSpex.Fixtures.create_visualization_for(context.owner_email, %{
            name: "Library Chart",
            vega_spec: %{"mark" => "line"}
          })

        {:ok, view, _html} = live(context.owner_conn, "/app/dashboards/new")

        view
        |> element("[data-role='add-visualization-btn']")
        |> render_click()

        {:ok, Map.merge(context, %{view: view, visualization: visualization})}
      end

      when_ "they insert that visualization into the report", context do
        context.view
        |> element("[data-role='library-visualization-option'][phx-value-id='#{context.visualization.id}']")
        |> render_click()

        {:ok, context}
      end

      then_ "the rendered chart appears inline alongside the report's other elements", context do
        html = render(context.view)
        assert has_element?(context.view, "[data-role='visualization-card']")
        assert html =~ "Library Chart"
        {:ok, context}
      end
    end
  end
end
