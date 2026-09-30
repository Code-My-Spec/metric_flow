defmodule MetricFlowSpex.Criterion172SetReportAsFavoriteSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "User can set report as favorite for quick access", criterion: 172 do
    scenario "marking a report as a favorite makes it available for quick access" do
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
        |> render_change(%{"name" => "Favorite Candidate"})

        new_view
        |> element("[data-role='save-visualization-btn']")
        |> render_click()

        {:ok, view, html} = live(context.owner_conn, "/app/reports")
        [_, report_id] = Regex.run(~r/data-report-id="(\d+)"/, html)

        {:ok, Map.merge(context, %{view: view, report_id: report_id})}
      end

      when_ "the user marks it as a favorite", context do
        assert has_element?(context.view, "[data-role='favorite-report-#{context.report_id}']"),
               "Expected a favorite control on the report card"

        context.view
        |> element("[data-role='favorite-report-#{context.report_id}']")
        |> render_click()

        {:ok, context}
      end

      then_ "it is available for quick access as a favorite", context do
        {:ok, view, html} = live(context.owner_conn, "/app/reports")

        assert has_element?(view, "[data-role='favorite-reports']") and
                 html =~ "Favorite Candidate"

        {:ok, context}
      end
    end
  end
end
