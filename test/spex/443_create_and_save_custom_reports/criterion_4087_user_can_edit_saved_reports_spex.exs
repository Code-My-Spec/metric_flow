defmodule MetricFlowSpex.Criterion4087EditSavedReportsSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "User can edit saved reports" do
    scenario "user creates a dashboard then edits it" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "user creates and saves a dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboards/new")

        view
        |> element("[data-role='template-card-marketing_overview']")
        |> render_click()

        view
        |> form("form[phx-change='validate_name']", dashboard: %{name: "Editable Report"})
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

      then_ "the dashboard has an edit link", context do
        html = render(context.view)
        assert html =~ "Editable Report"
        assert html =~ "/edit"
        :ok
      end
    end
  end
end
