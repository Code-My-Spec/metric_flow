defmodule MetricFlowSpex.Criterion789SavingAReportPersistsChartSettingsSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Saving a report persists each chart's settings", criterion: 789 do
    scenario "a dashboard's chart settings are persisted and restored the next time it is viewed" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription
      given_ :owner_has_metrics

      given_ "a dashboard containing charts with specific types and layout", context do
        {:ok, new_view, _html} = live(context.owner_conn, "/app/dashboards/new")

        new_view
        |> element("[data-role='add-visualization-btn']")
        |> render_click()

        new_view
        |> element("[phx-click='select_metric'][phx-value-metric='impressions']")
        |> render_click()

        new_view
        |> element("[phx-click='select_chart_type'][phx-value-chart_type='bar']")
        |> render_click()

        new_view
        |> element("[data-role='confirm-add-btn']")
        |> render_click()

        {:ok, context}
      end

      when_ "the user saves the dashboard and reopens it for editing", context do
        {:ok, new_view, _html} = live(context.owner_conn, "/app/dashboards/new")

        new_view
        |> element("[data-role='add-visualization-btn']")
        |> render_click()

        new_view
        |> element("[phx-click='select_metric'][phx-value-metric='impressions']")
        |> render_click()

        new_view
        |> element("[phx-click='select_chart_type'][phx-value-chart_type='bar']")
        |> render_click()

        new_view
        |> element("[data-role='confirm-add-btn']")
        |> render_click()

        new_view
        |> element("form[phx-change='validate_name']")
        |> render_change(%{"dashboard" => %{"name" => "Persisted Dashboard"}})

        {:error, {:live_redirect, %{to: path}}} =
          new_view
          |> element("[data-role='save-dashboard-btn']")
          |> render_click()

        [_, dashboard_id] = Regex.run(~r{/app/dashboards/(\d+)}, path)

        {:ok, edit_view, _html} =
          live(context.owner_conn, "/app/dashboards/#{dashboard_id}/edit")

        {:ok, Map.put(context, :edit_view, edit_view)}
      end

      then_ "the reopened dashboard shows the same chart with its saved settings", context do
        html = render(context.edit_view)
        assert html =~ "impressions"
        assert html =~ "bar"
        {:ok, context}
      end
    end
  end
end
