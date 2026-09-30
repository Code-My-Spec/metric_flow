defmodule MetricFlowSpex.Criterion245NameAndSaveVisualizationSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "User can name and save the visualization, making it available for inclusion in custom reports",
    criterion: 245 do
    scenario "a user builds a visualization in the authoring workspace and names and saves it" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription
      given_ :owner_has_metrics

      given_ "a user has built a visualization in the authoring workspace", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/visualizations/new")

        view
        |> element("[phx-value-metric='impressions']")
        |> render_click()

        {:ok, Map.put(context, :view, view)}
      end

      when_ "they name and save it", context do
        context.view
        |> element("form[phx-change='validate_name']")
        |> render_change(%{"name" => "My Custom Report Chart"})

        result =
          context.view
          |> element("[data-role='save-visualization-btn']")
          |> render_click()

        {:ok, Map.put(context, :save_result, result)}
      end

      then_ "it becomes available for inclusion in custom reports", context do
        case context.save_result do
          {:error, {:live_redirect, %{to: path}}} ->
            assert path == "/app/dashboards"

          _ ->
            :ok
        end

        {:ok, index_view, html} = live(context.owner_conn, "/app/visualizations")
        assert html =~ "My Custom Report Chart"
        {:ok, Map.put(context, :library_view, index_view)}
      end
    end
  end
end
