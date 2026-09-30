defmodule MetricFlowSpex.Criterion169ReportsSortedByLastModifiedSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Reports are sorted by last modified date", criterion: 169 do
    scenario "a report edited after another still-newer report appears first" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription
      given_ :owner_has_metrics

      given_ "the user saves an older report, then a newer report", context do
        {:ok, first_view, _html} = live(context.owner_conn, "/app/visualizations/new")

        first_view
        |> element("[phx-value-metric='impressions']")
        |> render_click()

        first_view
        |> element("form[phx-change='validate_name']")
        |> render_change(%{"name" => "Older Report"})

        first_view
        |> element("[data-role='save-visualization-btn']")
        |> render_click()

        {:ok, second_view, _html} = live(context.owner_conn, "/app/visualizations/new")

        second_view
        |> element("[phx-value-metric='clicks']")
        |> render_click()

        second_view
        |> element("form[phx-change='validate_name']")
        |> render_change(%{"name" => "Newer Report"})

        second_view
        |> element("[data-role='save-visualization-btn']")
        |> render_click()

        {:ok, context}
      end

      when_ "the user reopens and re-saves the older report, changing its content", context do
        {:ok, index_view, _html} = live(context.owner_conn, "/app/reports")
        html = render(index_view)
        [_, older_id] = Regex.run(~r/data-report-id="(\d+)".*?Older Report/s, html)

        {:ok, edit_view, _html} =
          live(context.owner_conn, "/app/visualizations/#{older_id}/edit")

        edit_view
        |> element("[phx-value-metric='conversions']")
        |> render_click()

        edit_view
        |> element("[data-role='save-visualization-btn']")
        |> render_click()

        {:ok, context}
      end

      then_ "the reports are ordered by last modified date, with the just-edited report first", context do
        {:ok, index_view, html} = live(context.owner_conn, "/app/reports")
        older_index = :binary.match(html, "Older Report") |> elem(0)
        newer_index = :binary.match(html, "Newer Report") |> elem(0)

        assert older_index < newer_index,
               "Expected the just-edited (older-created) report to sort before the untouched newer report"

        {:ok, Map.put(context, :view, index_view)}
      end
    end
  end
end
