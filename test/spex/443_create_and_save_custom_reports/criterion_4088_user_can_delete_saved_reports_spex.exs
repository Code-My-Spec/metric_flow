defmodule MetricFlowSpex.Criterion4088DeleteSavedReportsSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "User can delete saved reports" do
    scenario "user creates a dashboard then deletes it" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "user creates and saves a dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/dashboards/new")

        view
        |> element("[data-role='template-card-marketing_overview']")
        |> render_click()

        view
        |> form("form[phx-change='validate_name']", dashboard: %{name: "Deletable Report"})
        |> render_change()

        view
        |> element("[data-role='save-dashboard-btn']")
        |> render_click()

        {:ok, context}
      end

      when_ "user navigates to dashboards and clicks delete", context do
        {:ok, view, _html} = live(context.owner_conn, "/dashboards")

        # Find the delete button (includes dashboard ID in data-role)
        html = render(view)
        assert html =~ "Deletable Report"

        # Click the delete button via phx-click
        view
        |> element("[phx-click='delete']")
        |> render_click()

        # Confirm deletion
        view
        |> element("[phx-click='confirm_delete']")
        |> render_click()

        html = render(view)
        {:ok, Map.merge(context, %{view: view, html: html})}
      end

      then_ "the deleted dashboard is no longer in the list", context do
        refute context.html =~ "Deletable Report"
        :ok
      end
    end
  end
end
