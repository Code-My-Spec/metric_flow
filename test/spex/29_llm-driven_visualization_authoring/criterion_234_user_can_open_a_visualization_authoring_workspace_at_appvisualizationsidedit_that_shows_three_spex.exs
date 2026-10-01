defmodule MetricFlowSpex.Criterion234AuthoringWorkspaceThreePanelsAtEditRouteSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "User can open a visualization authoring workspace at /app/visualizations/:id/edit that shows three panels: a chat panel on the left, a live chart preview in the center, and a slide-out Vega-Lite JSON spec editor on the right",
    criterion: 234 do
    scenario "opening a saved visualization for editing shows the chat, preview, and spec editor panels" do
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
        |> render_change(%{"name" => "Workspace Panels"})

        new_view
        |> element("[data-role='save-visualization-btn']")
        |> render_click()

        {:ok, index_view, _html} = live(context.owner_conn, "/app/visualizations")
        html = render(index_view)
        [_, viz_id] = Regex.run(~r/data-visualization-id="(\d+)"/, html)

        {:ok, Map.put(context, :viz_id, viz_id)}
      end

      when_ "the user navigates to /app/visualizations/:id/edit", context do
        {:ok, view, _html} =
          live(context.owner_conn, "/app/visualizations/#{context.viz_id}/edit")

        {:ok, Map.put(context, :view, view)}
      end

      then_ "it shows a chat panel, a live chart preview, and a spec editor toggle", context do
        assert has_element?(context.view, "[data-role='chat-panel']")
        assert has_element?(context.view, "[data-role='chat-form']")
        assert has_element?(context.view, "[data-role='spec-panel']")
        assert has_element?(context.view, "[data-role='open-spec-panel']")
        assert has_element?(context.view, "[data-role='chart-preview-section']")
        {:ok, context}
      end
    end
  end
end
