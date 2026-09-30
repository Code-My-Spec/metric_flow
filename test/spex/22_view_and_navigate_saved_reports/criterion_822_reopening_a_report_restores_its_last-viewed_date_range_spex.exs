defmodule MetricFlowSpex.Criterion822ReopeningRestoresLastViewedDateRangeSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Reopening a report restores its last-viewed date range", criterion: 822 do
    scenario "reopening a report later shows the same date range selected previously" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription
      given_ :owner_has_metrics

      given_ "a user previously viewed a report with a specific date range selected", context do
        {:ok, new_view, _html} = live(context.owner_conn, "/app/visualizations/new")

        new_view
        |> element("[phx-value-metric='impressions']")
        |> render_click()

        new_view
        |> element("form[phx-change='validate_name']")
        |> render_change(%{"name" => "Persisted Range Report"})

        new_view
        |> element("[data-role='save-visualization-btn']")
        |> render_click()

        {:ok, _index_view, html} = live(context.owner_conn, "/app/reports")
        [_, report_id] = Regex.run(~r/data-report-id="(\d+)"/, html)

        {:ok, first_view, _html} = live(context.owner_conn, "/app/reports/#{report_id}")

        assert has_element?(first_view, "[data-role='date-range-filter']"),
               "Expected a date range selector on the report page"

        first_view
        |> element("[phx-click='filter_date_range'][phx-value-range='last_7_days']")
        |> render_click()

        {:ok, Map.put(context, :report_id, report_id)}
      end

      when_ "they reopen that report later", context do
        {:ok, second_view, _html} = live(context.owner_conn, "/app/reports/#{context.report_id}")
        {:ok, Map.put(context, :view, second_view)}
      end

      then_ "it shows the same date range that was selected the last time it was viewed", context do
        assert context.view
               |> element("[phx-value-range='last_7_days'].btn-primary")
               |> has_element?()

        {:ok, context}
      end
    end
  end
end
