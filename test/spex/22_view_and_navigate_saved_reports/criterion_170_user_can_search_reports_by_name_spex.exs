defmodule MetricFlowSpex.Criterion170UserCanSearchReportsByNameSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "User can search reports by name", criterion: 170 do
    scenario "searching by a report's name filters the visible reports" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription
      given_ :owner_has_metrics

      given_ "the user has two saved reports with different names", context do
        {:ok, view_a, _html} = live(context.owner_conn, "/app/visualizations/new")

        view_a
        |> element("[phx-value-metric='impressions']")
        |> render_click()

        view_a
        |> element("form[phx-change='validate_name']")
        |> render_change(%{"name" => "Quarterly Revenue"})

        view_a
        |> element("[data-role='save-visualization-btn']")
        |> render_click()

        {:ok, view_b, _html} = live(context.owner_conn, "/app/visualizations/new")

        view_b
        |> element("[phx-value-metric='clicks']")
        |> render_click()

        view_b
        |> element("form[phx-change='validate_name']")
        |> render_change(%{"name" => "Weekly Clicks"})

        view_b
        |> element("[data-role='save-visualization-btn']")
        |> render_click()

        {:ok, view, _html} = live(context.owner_conn, "/app/reports")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user searches by one report's name", context do
        assert has_element?(context.view, "[data-role='report-search-input']"),
               "Expected a search input on the reports list"

        context.view
        |> form("#report-search-form", %{"search" => "Quarterly"})
        |> render_change()

        {:ok, context}
      end

      then_ "the list filters to reports matching that name", context do
        html = render(context.view)
        assert html =~ "Quarterly Revenue"
        refute html =~ "Weekly Clicks"
        {:ok, context}
      end
    end
  end
end
