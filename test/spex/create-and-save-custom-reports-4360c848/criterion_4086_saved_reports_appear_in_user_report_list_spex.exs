defmodule MetricFlowSpex.Criterion4086SavedReportsInListSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Saved reports appear in user report list" do
    scenario "after saving a dashboard, it appears on the dashboards index" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "user creates and saves a dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboards/new")

        view
        |> element("[data-role='template-card-marketing_overview']")
        |> render_click()

        view
        |> form("form[phx-change='validate_name']", dashboard: %{name: "Listed Report"})
        |> render_change()

        view
        |> element("[data-role='save-dashboard-btn']")
        |> render_click()

        {:ok, context}
      end

      when_ "user navigates to the dashboards list", context do
        {:ok, view, html} = live(context.owner_conn, "/app/dashboards")
        {:ok, Map.merge(context, %{view: view, html: html})}
      end

      then_ "the saved dashboard appears in the list", context do
        assert context.html =~ "Listed Report"
        :ok
      end
    end
  end
end
