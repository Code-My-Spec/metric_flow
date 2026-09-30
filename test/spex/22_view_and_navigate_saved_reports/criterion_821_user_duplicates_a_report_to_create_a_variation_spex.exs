defmodule MetricFlowSpex.Criterion821UserDuplicatesReportSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "User duplicates a report to create a variation", criterion: 821 do
    scenario "duplicating a report creates a new independent copy" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription
      given_ :owner_has_metrics

      given_ "a user viewing a saved report", context do
        {:ok, new_view, _html} = live(context.owner_conn, "/app/visualizations/new")

        new_view
        |> element("[phx-value-metric='impressions']")
        |> render_click()

        new_view
        |> element("form[phx-change='validate_name']")
        |> render_change(%{"name" => "Report To Duplicate"})

        new_view
        |> element("[data-role='save-visualization-btn']")
        |> render_click()

        {:ok, view, html} = live(context.owner_conn, "/app/reports")
        [_, report_id] = Regex.run(~r/data-report-id="(\d+)"/, html)

        {:ok, Map.merge(context, %{view: view, report_id: report_id})}
      end

      when_ "they duplicate it", context do
        assert has_element?(context.view, "[data-role='duplicate-report-#{context.report_id}']"),
               "Expected a duplicate control on the report card"

        context.view
        |> element("[data-role='duplicate-report-#{context.report_id}']")
        |> render_click()

        {:ok, context}
      end

      then_ "a new independent copy is created that they can modify without affecting the original", context do
        {:ok, _view, html} = live(context.owner_conn, "/app/reports")

        assert length(Regex.scan(~r/data-report-id="(\d+)"/, html)) == 2,
               "Expected a second, independent report after duplicating"

        {:ok, context}
      end
    end
  end
end
