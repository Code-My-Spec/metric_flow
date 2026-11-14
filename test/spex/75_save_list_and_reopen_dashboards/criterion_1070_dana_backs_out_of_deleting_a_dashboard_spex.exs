defmodule MetricFlowSpex.Story75.Criterion1070Spex do
  @moduledoc """
  Story 75 — Save, List and Reopen Dashboards
  Criterion 1070 — Cancelling the delete confirmation leaves the
  dashboard untouched.
  """

  use MetricFlowSpex.Case, async: false

  import MetricFlowSpex.SharedGivens

  spex "Dana backs out of deleting a dashboard", criterion: 1070 do
    scenario "cancelling at the confirmation step leaves it in the list" do
      given_(:user_logged_in_as_owner)
      given_(:owner_has_metrics)

      given_ "Dana chose to delete a dashboard but has not confirmed", context do
        {:ok, view, _html} = live(context.owner_conn, ~p"/app/dashboards/new")

        Application.put_env(
          :metric_flow,
          :command_runner,
          MetricFlowTest.DashboardBuilderStub.generate_initial()
        )

        render_submit(view, "send_dashboard_chat", %{"message" => "Show me impressions"})
        Process.sleep(100)
        Application.delete_env(:metric_flow, :command_runner)

        {:ok, index_view, index_html} = live(context.owner_conn, ~p"/app/dashboards")

        [dashboard_id] =
          index_html
          |> Floki.parse_fragment!()
          |> Floki.find("[data-role^='edit-dashboard-']")
          |> Floki.attribute("data-role")
          |> Enum.map(&String.replace_prefix(&1, "edit-dashboard-", ""))

        index_view
        |> element("[data-role='delete-dashboard-#{dashboard_id}']")
        |> render_click()

        assert has_element?(index_view, "[data-role='delete-confirm-#{dashboard_id}']")
        {:ok, Map.merge(context, %{index_view: index_view, dashboard_id: dashboard_id})}
      end

      when_ "she cancels at the confirmation", context do
        context.index_view
        |> element("[data-role='cancel-delete']")
        |> render_click()

        {:ok, context}
      end

      then_ "the dashboard is still in her list unchanged", context do
        assert has_element?(
                 context.index_view,
                 "[data-role='edit-dashboard-#{context.dashboard_id}']"
               )

        refute has_element?(
                 context.index_view,
                 "[data-role='delete-confirm-#{context.dashboard_id}']"
               )

        {:ok, context}
      end
    end
  end
end
