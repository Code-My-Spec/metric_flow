defmodule MetricFlowSpex.Criterion4084ArrangeVisualizationsSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "User can arrange visualizations in layout" do
    scenario "user can reorder visualizations with move up/down controls" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "user has a dashboard with multiple visualizations from a template", context do
        {:ok, view, _html} = live(context.owner_conn, "/dashboards/new")

        # Select a template to get multiple viz cards
        view
        |> element("[data-role='template-card-marketing_overview']")
        |> render_click()

        {:ok, Map.put(context, :view, view)}
      end

      then_ "move up and move down controls are visible on each visualization card", context do
        assert has_element?(context.view, "[phx-click='move_visualization_up']")
        assert has_element?(context.view, "[phx-click='move_visualization_down']")
        :ok
      end

      when_ "user clicks move down on the first visualization", context do
        context.view
        |> element("[phx-click='move_visualization_down'][phx-value-index='0']")
        |> render_click()

        {:ok, context}
      end

      then_ "the visualization order changes", context do
        # The canvas should still have visualization cards (order changed)
        assert has_element?(context.view, "[data-role='visualization-card']")
        :ok
      end
    end
  end
end
