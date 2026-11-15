defmodule MetricFlowSpex.Story75.Criterion1080Spex do
  @moduledoc """
  Story 75 — Save, List and Reopen Dashboards
  Criterion 1080 — A dashboard's earlier versions are listed and
  restorable only in Edit with agent, not on the view page.
  """

  use MetricFlowSpex.Case, async: false

  import MetricFlowSpex.SharedGivens

  spex "Dana finds versions only when editing", criterion: 1080 do
    scenario "the view page hides the version list that Edit with agent shows" do
      given_(:user_logged_in_as_owner)
      given_(:owner_has_metrics)

      given_ "Dana's dashboard has several versions", context do
        {:ok, view, _html} = live(context.owner_conn, ~p"/app/dashboards/new")

        Application.put_env(
          :metric_flow,
          :command_runner,
          MetricFlowTest.DashboardBuilderStub.generate_initial()
        )

        render_submit(view, "send_dashboard_chat", %{"message" => "Show me impressions"})
        await_dashboard_chat_completion(view)
        Application.delete_env(:metric_flow, :command_runner)

        Application.put_env(
          :metric_flow,
          :command_runner,
          MetricFlowTest.DashboardBuilderStub.generate_followup()
        )

        render_submit(view, "send_dashboard_chat", %{"message" => "Add clicks as a second chart"})
        await_dashboard_chat_completion(view)
        Application.delete_env(:metric_flow, :command_runner)

        {:ok, _index_view, index_html} = live(context.owner_conn, ~p"/app/dashboards")

        [view_href | _] =
          index_html
          |> Floki.parse_fragment!()
          |> Floki.find("[data-role='user-dashboards'] a[data-role^='view-dashboard-']")
          |> Floki.attribute("href")

        {:ok, Map.put(context, :view_href, view_href)}
      end

      when_ "she opens it on the view page", context do
        {:ok, show_view, _show_html} = live(context.owner_conn, context.view_href)
        {:ok, Map.put(context, :show_view, show_view)}
      end

      then_ "no versions list is shown", context do
        refute has_element?(context.show_view, "[data-role='dashboard-version-list']")
        {:ok, context}
      end

      then_ "choosing Edit with agent shows the versions beside the chat", context do
        [edit_href | _] =
          render(context.show_view)
          |> Floki.parse_fragment!()
          |> Floki.find("a[data-role^='edit-dashboard-']")
          |> Floki.attribute("href")

        {:ok, edit_view, _edit_html} = live(context.owner_conn, edit_href)
        assert has_element?(edit_view, "[data-role='dashboard-version-list']")
        {:ok, context}
      end
    end
  end
end
