defmodule MetricFlowSpex.Story75.Criterion1069Spex do
  @moduledoc """
  Story 75 — Save, List and Reopen Dashboards
  Criterion 1069 — Deleting a dashboard, after confirmation, removes it
  permanently along with its chat history and versions.
  """

  use MetricFlowSpex.Case, async: false

  import MetricFlowSpex.SharedGivens

  spex "Dana deletes a dashboard she no longer needs", criterion: 1069 do
    scenario "confirming delete removes the dashboard and everything it carried" do
      given_(:user_logged_in_as_owner)
      given_(:owner_has_metrics)

      given_ "Dana has a dashboard called 'Old test'", context do
        {:ok, view, _html} = live(context.owner_conn, ~p"/app/dashboards/new")

        Application.put_env(
          :metric_flow,
          :command_runner,
          MetricFlowTest.DashboardBuilderStub.generate_initial()
        )

        render_submit(view, "send_dashboard_chat", %{"message" => "Show me impressions"})
        await_dashboard_chat_completion(view)
        Application.delete_env(:metric_flow, :command_runner)

        {:ok, _index_view, index_html} = live(context.owner_conn, ~p"/app/dashboards")

        [dashboard_id] =
          index_html
          |> Floki.parse_fragment!()
          |> Floki.find("[data-role^='edit-dashboard-']")
          |> Floki.attribute("data-role")
          |> Enum.map(&String.replace_prefix(&1, "edit-dashboard-", ""))

        {:ok, index_view, _html} = live(context.owner_conn, ~p"/app/dashboards")

        index_view
        |> element("[data-role='rename-dashboard-#{dashboard_id}']")
        |> render_click()

        index_view
        |> form("[data-role='rename-form-#{dashboard_id}'] form", %{"name" => "Old test"})
        |> render_submit()

        {:ok, Map.merge(context, %{index_view: index_view, dashboard_id: dashboard_id})}
      end

      when_ "she deletes it and confirms", context do
        context.index_view
        |> element("[data-role='delete-dashboard-#{context.dashboard_id}']")
        |> render_click()

        context.index_view
        |> element("[data-role='confirm-delete-#{context.dashboard_id}']")
        |> render_click()

        {:ok, context}
      end

      then_ "it no longer appears in her list", context do
        html = render(context.index_view)
        refute html =~ "Old test"

        refute has_element?(
                 context.index_view,
                 "[data-role='edit-dashboard-#{context.dashboard_id}']"
               )

        {:ok, context}
      end

      then_ "its chat history and versions are gone", context do
        assert {:error, {:redirect, %{to: "/app/dashboards"}}} =
                 live(context.owner_conn, ~p"/app/dashboards/#{context.dashboard_id}/edit")

        {:ok, context}
      end
    end
  end
end
