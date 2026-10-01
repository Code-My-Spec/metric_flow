defmodule MetricFlowSpex.Criterion806WorkspaceShowsChatPreviewSpecEditorSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Authoring workspace shows chat, preview, and spec editor panels", criterion: 806 do
    scenario "navigating to /app/visualizations/:id/edit shows all three panels" do
      given_(:user_logged_in_as_owner)
      given_(:owner_has_active_subscription)
      given_(:owner_has_metrics)

      given_ "a saved visualization", context do
        {:ok, new_view, _html} = live(context.owner_conn, "/app/visualizations/new")

        new_view
        |> element("[phx-value-metric='impressions']")
        |> render_click()

        new_view
        |> element("form[phx-change='validate_name']")
        |> render_change(%{"name" => "Panels Check"})

        new_view
        |> element("[data-role='save-visualization-btn']")
        |> render_click()

        {:ok, index_view, _html} = live(context.owner_conn, "/app/visualizations")
        html = render(index_view)
        [_, viz_id] = Regex.run(~r/data-visualization-id="(\d+)"/, html)

        {:ok, Map.put(context, :viz_id, viz_id)}
      end

      when_ "a user navigates to /app/visualizations/:id/edit", context do
        {:ok, view, _html} =
          live(context.owner_conn, "/app/visualizations/#{context.viz_id}/edit")

        {:ok, Map.put(context, :view, view)}
      end

      then_ "it shows a chat panel, a live rendered preview, and a slide-out Vega-Lite spec editor",
            context do
        assert has_element?(context.view, "[data-role='chat-panel']")
        assert has_element?(context.view, "[data-role='chart-preview-section']")
        assert has_element?(context.view, "[data-role='spec-panel']")
        {:ok, context}
      end
    end
  end
end
