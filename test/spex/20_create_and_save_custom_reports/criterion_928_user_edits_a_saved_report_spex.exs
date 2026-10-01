defmodule MetricFlowSpex.UserEditsASavedReportSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "User edits a saved report", criterion: 928 do
    scenario "opening a saved report, changing it, and saving again reflects the changes" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "a user has a previously saved report", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboards/new")

        view
        |> element("[data-role='template-card-marketing_overview']")
        |> render_click()

        view
        |> form("form[phx-change='validate_name']", dashboard: %{name: "Original Report Name"})
        |> render_change()

        view
        |> element("[data-role='save-dashboard-btn']")
        |> render_click()

        {path, _flash} = assert_redirect(view)
        {:ok, Map.put(context, :dashboard_path, path)}
      end

      when_ "they open it and make changes, then save again", context do
        {:ok, edit_view, _html} =
          live(context.owner_conn, context.dashboard_path <> "/edit")

        edit_view
        |> form("form[phx-change='validate_name']", dashboard: %{name: "Updated Report Name"})
        |> render_change()

        edit_view
        |> element("[data-role='save-dashboard-btn']")
        |> render_click()

        {:ok, context}
      end

      then_ "the saved report reflects those changes", context do
        {:ok, _list_view, html} = live(context.owner_conn, "/app/dashboards")
        assert html =~ "Updated Report Name"
        refute html =~ "Original Report Name"
        {:ok, context}
      end
    end
  end
end
