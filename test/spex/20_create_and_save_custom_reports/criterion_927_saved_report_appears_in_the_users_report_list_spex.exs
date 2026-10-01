defmodule MetricFlowSpex.SavedReportAppearsInTheUsersReportListSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Saved report appears in the user's report list", criterion: 927 do
    scenario "a just-saved report shows up when the user views their report list" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "a user has just saved a report", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboards/new")

        view
        |> element("[data-role='template-card-marketing_overview']")
        |> render_click()

        view
        |> form("form[phx-change='validate_name']", dashboard: %{name: "Just Saved Report"})
        |> render_change()

        view
        |> element("[data-role='save-dashboard-btn']")
        |> render_click()

        {:ok, context}
      end

      when_ "they view their report list", context do
        {:ok, view, html} = live(context.owner_conn, "/app/dashboards")
        {:ok, Map.merge(context, %{view: view, html: html})}
      end

      then_ "the saved report appears there", context do
        assert context.html =~ "Just Saved Report"
        {:ok, context}
      end
    end
  end
end
