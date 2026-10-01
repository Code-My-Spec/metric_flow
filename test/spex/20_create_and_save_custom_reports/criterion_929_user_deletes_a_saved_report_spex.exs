defmodule MetricFlowSpex.UserDeletesASavedReportSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "User deletes a saved report", criterion: 929 do
    scenario "deleting a saved report removes it from the report list" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "a user has a saved report", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboards/new")

        view
        |> element("[data-role='template-card-marketing_overview']")
        |> render_click()

        view
        |> form("form[phx-change='validate_name']", dashboard: %{name: "Report To Delete"})
        |> render_change()

        view
        |> element("[data-role='save-dashboard-btn']")
        |> render_click()

        {:ok, context}
      end

      when_ "they delete it", context do
        {:ok, list_view, _html} = live(context.owner_conn, "/app/dashboards")

        list_view
        |> element("[phx-click='delete']")
        |> render_click()

        list_view
        |> element("[phx-click='confirm_delete']")
        |> render_click()

        html = render(list_view)
        {:ok, Map.merge(context, %{list_view: list_view, html: html})}
      end

      then_ "it no longer appears in their report list", context do
        refute context.html =~ "Report To Delete"
        {:ok, context}
      end
    end
  end
end
