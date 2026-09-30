defmodule MetricFlowSpex.Criterion790SavedVisualizationRendersInlineInDashboardSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Saved visualization renders inline in a dashboard", criterion: 790 do
    scenario "a user views a dashboard that includes a saved visualization" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription
      given_ :owner_has_metrics

      given_ "a dashboard saved with one visualization", context do
        {:ok, new_view, _html} = live(context.owner_conn, "/app/dashboards/new")

        new_view
        |> element("[data-role='add-visualization-btn']")
        |> render_click()

        new_view
        |> element("[phx-click='select_metric'][phx-value-metric='impressions']")
        |> render_click()

        new_view
        |> element("[data-role='confirm-add-btn']")
        |> render_click()

        new_view
        |> element("form[phx-change='validate_name']")
        |> render_change(%{"dashboard" => %{"name" => "Inline Render Dashboard"}})

        {:error, {:live_redirect, %{to: path}}} =
          new_view
          |> element("[data-role='save-dashboard-btn']")
          |> render_click()

        [_, dashboard_id] = Regex.run(~r{/app/dashboards/(\d+)}, path)

        {:ok, Map.put(context, :dashboard_id, dashboard_id)}
      end

      when_ "the user views that dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboards/#{context.dashboard_id}/edit")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the visualization renders inline as a real chart, not a placeholder", context do
        card_html =
          context.view
          |> element("[data-role='visualization-card']")
          |> render()

        assert card_html =~ "data-role=\"vega-lite-chart\"",
               "Expected the dashboard's attached visualization to render its actual chart inline, got: #{card_html}"

        {:ok, context}
      end
    end
  end
end
