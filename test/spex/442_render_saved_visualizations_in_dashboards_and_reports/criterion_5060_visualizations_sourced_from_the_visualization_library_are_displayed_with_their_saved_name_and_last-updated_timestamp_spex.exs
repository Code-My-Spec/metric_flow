defmodule MetricFlowSpex.Criterion5060VizLibraryShowsNameAndTimestampSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Visualizations in the library display their saved name and last-updated timestamp" do
    scenario "saved visualization appears in the library with name and timestamp" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription
      given_ :owner_has_metrics

      given_ "user creates and saves a visualization", context do
        {:ok, view, _html} = live(context.owner_conn, "/visualizations/new")

        view
        |> form("form[phx-change='validate_name']", name: "Library Viz Test")
        |> render_change()

        view
        |> element("[phx-value-metric='impressions']")
        |> render_click()

        view
        |> element("[data-role='save-visualization-btn']")
        |> render_click()

        {:ok, context}
      end

      when_ "user visits the visualization library", context do
        {:ok, view, html} = live(context.owner_conn, "/visualizations")
        {:ok, Map.merge(context, %{view: view, html: html})}
      end

      then_ "the visualization name is displayed", context do
        assert context.html =~ "Library Viz Test"
        :ok
      end

      then_ "an updated timestamp is visible", context do
        html = render(context.view)
        # Should show some form of timestamp (date, "ago", etc.)
        assert html =~ ~r/\d{4}/ || html =~ "ago" || html =~ "today" || html =~ "Updated",
               "Expected a timestamp or date to be displayed for the visualization"
        :ok
      end
    end
  end
end
