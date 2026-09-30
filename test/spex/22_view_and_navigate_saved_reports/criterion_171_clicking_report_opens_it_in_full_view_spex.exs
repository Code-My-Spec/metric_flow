defmodule MetricFlowSpex.Criterion171ClickingReportOpensFullViewSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Clicking report opens it in full view", criterion: 171 do
    scenario "clicking a report in the list opens its full view" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription
      given_ :owner_has_metrics

      given_ "a saved report and the user viewing the reports list", context do
        {:ok, new_view, _html} = live(context.owner_conn, "/app/visualizations/new")

        new_view
        |> element("[phx-value-metric='impressions']")
        |> render_click()

        new_view
        |> element("form[phx-change='validate_name']")
        |> render_change(%{"name" => "Clickable Report"})

        new_view
        |> element("[data-role='save-visualization-btn']")
        |> render_click()

        {:ok, view, _html} = live(context.owner_conn, "/app/reports")
        html = render(view)
        [_, report_id] = Regex.run(~r/data-report-id="(\d+)"/, html)

        {:ok, Map.merge(context, %{view: view, report_id: report_id})}
      end

      when_ "they click the report", context do
        result =
          context.view
          |> element("[data-role='view-report-#{context.report_id}']")
          |> render_click()

        {:ok, Map.put(context, :click_result, result)}
      end

      then_ "it opens in full view", context do
        case context.click_result do
          {:error, {:live_redirect, %{to: path}}} ->
            assert path == "/app/visualizations/#{context.report_id}/edit"
            {:ok, view, _html} = live(context.owner_conn, path)
            assert has_element?(view, "[data-role='chart-preview-section']") or
                     has_element?(view, "[data-role='vega-lite-chart']")

          _ ->
            flunk("Expected clicking the report to navigate to its full view")
        end

        {:ok, context}
      end
    end
  end
end
