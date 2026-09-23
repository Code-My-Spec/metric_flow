defmodule MetricFlowSpex.Criterion4085NameAndSaveReportSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "User can name and save report" do
    scenario "user names a dashboard, adds a visualization, and saves" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "user is on the new dashboard page with a template selected", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboards/new")

        view
        |> element("[data-role='template-card-marketing_overview']")
        |> render_click()

        {:ok, Map.put(context, :view, view)}
      end

      when_ "user enters a name and saves", context do
        context.view
        |> form("form[phx-change='validate_name']", dashboard: %{name: "My Custom Report"})
        |> render_change()

        context.view
        |> element("[data-role='save-dashboard-btn']")
        |> render_click()

        {:ok, context}
      end

      then_ "the dashboard is saved and user is redirected to dashboards", context do
        {path, _} = assert_redirect(context.view)
        assert path =~ "/app/dashboards"
        :ok
      end
    end
  end
end
