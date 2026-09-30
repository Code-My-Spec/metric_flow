defmodule MetricFlowSpex.Criterion816ReportsListSortedByLastModifiedSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Reports list is sorted by last modified date", criterion: 816 do
    scenario "reports modified at different times are ordered by last modified date" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription
      given_ :owner_has_metrics

      given_ "a user has saved reports modified at different times", context do
        {:ok, first_view, _html} = live(context.owner_conn, "/app/visualizations/new")

        first_view
        |> element("[phx-value-metric='impressions']")
        |> render_click()

        first_view
        |> element("form[phx-change='validate_name']")
        |> render_change(%{"name" => "First Saved"})

        first_view
        |> element("[data-role='save-visualization-btn']")
        |> render_click()

        {:ok, second_view, _html} = live(context.owner_conn, "/app/visualizations/new")

        second_view
        |> element("[phx-value-metric='clicks']")
        |> render_click()

        second_view
        |> element("form[phx-change='validate_name']")
        |> render_change(%{"name" => "Second Saved"})

        second_view
        |> element("[data-role='save-visualization-btn']")
        |> render_click()

        {:ok, html} =
          (fn ->
            {:ok, _view, html} = live(context.owner_conn, "/app/reports")
            {:ok, html}
          end).()

        [_, first_id] = Regex.run(~r/data-report-id="(\d+)".*?First Saved/s, html)

        {:ok, edit_view, _html} =
          live(context.owner_conn, "/app/visualizations/#{first_id}/edit")

        edit_view
        |> element("[phx-value-metric='conversions']")
        |> render_click()

        edit_view
        |> element("[data-role='save-visualization-btn']")
        |> render_click()

        {:ok, context}
      end

      when_ "they view the reports list", context do
        {:ok, view, html} = live(context.owner_conn, "/app/reports")
        {:ok, Map.merge(context, %{view: view, html: html})}
      end

      then_ "the reports are ordered by last modified date", context do
        first_index = :binary.match(context.html, "First Saved") |> elem(0)
        second_index = :binary.match(context.html, "Second Saved") |> elem(0)

        assert first_index < second_index,
               "Expected the just-modified report (First Saved) to sort before the untouched Second Saved"

        {:ok, context}
      end
    end
  end
end
