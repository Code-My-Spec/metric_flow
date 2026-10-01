defmodule MetricFlowSpex.UserNamesAndSavesAReportSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "User names and saves a report", criterion: 926 do
    scenario "naming and saving a built report persists it under that name" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "a user has built a report", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboards/new")

        view
        |> element("[data-role='template-card-marketing_overview']")
        |> render_click()

        {:ok, Map.put(context, :view, view)}
      end

      when_ "they name it and save", context do
        context.view
        |> form("form[phx-change='validate_name']", dashboard: %{name: "Weekly Marketing Report"})
        |> render_change()

        context.view
        |> element("[data-role='save-dashboard-btn']")
        |> render_click()

        {:ok, context}
      end

      then_ "the report is saved under that name", context do
        assert_redirect(context.view)

        {:ok, list_view, html} = live(context.owner_conn, "/app/dashboards")
        assert html =~ "Weekly Marketing Report"
        {:ok, Map.put(context, :list_view, list_view)}
      end
    end
  end
end
