defmodule MetricFlowSpex.Criterion818SearchNoMatchShowsEmptyResultSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Search with no matching reports shows an empty result", criterion: 818 do
    scenario "searching for a name no report matches shows an empty result rather than an error" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription
      given_ :owner_has_metrics

      given_ "a user searching their saved reports", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/visualizations/new")

        view
        |> element("[phx-value-metric='impressions']")
        |> render_click()

        view
        |> element("form[phx-change='validate_name']")
        |> render_change(%{"name" => "Existing Report"})

        view
        |> element("[data-role='save-visualization-btn']")
        |> render_click()

        {:ok, index_view, _html} = live(context.owner_conn, "/app/reports")

        assert has_element?(index_view, "[data-role='report-search-input']"),
               "Expected a search input on the reports list"

        {:ok, Map.put(context, :view, index_view)}
      end

      when_ "no report name matches the search term", context do
        context.view
        |> form("#report-search-form", %{"search" => "no-such-report-name-xyz"})
        |> render_change()

        {:ok, context}
      end

      then_ "the list shows an empty result rather than an error", context do
        html = render(context.view)
        refute html =~ "Existing Report"
        assert has_element?(context.view, "[data-role='empty-reports']") or
                 has_element?(context.view, "[data-role='no-search-results']")

        {:ok, context}
      end
    end
  end
end
