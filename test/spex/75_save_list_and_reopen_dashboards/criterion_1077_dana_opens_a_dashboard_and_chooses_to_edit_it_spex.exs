defmodule MetricFlowSpex.Story75.Criterion1077Spex do
  @moduledoc """
  Story 75 — Save, List and Reopen Dashboards
  Criterion 1077 — Clicking a dashboard opens a view page with an Edit
  with agent button that opens the chat to refine it.
  """

  use MetricFlowSpex.Case, async: false

  import MetricFlowSpex.SharedGivens

  spex "Dana opens a dashboard and chooses to edit it", criterion: 1077 do
    scenario "the view page has an Edit with agent button that opens the chat" do
      given_(:user_logged_in_as_owner)
      given_(:owner_has_metrics)

      given_ "Dana has a saved dashboard", context do
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

        [view_href | _] =
          index_html
          |> Floki.parse_fragment!()
          |> Floki.find("[data-role='user-dashboards'] a[data-role^='view-dashboard-']")
          |> Floki.attribute("href")

        {:ok, Map.put(context, :view_href, view_href)}
      end

      when_ "she clicks it in the list", context do
        {:ok, show_view, show_html} = live(context.owner_conn, context.view_href)
        {:ok, Map.merge(context, %{show_view: show_view, show_html: show_html})}
      end

      then_ "she sees the dashboard with her saved filters and an Edit with agent button",
            context do
        assert has_element?(context.show_view, "[data-role='filter-control']")

        [edit_href | _] =
          context.show_html
          |> Floki.parse_fragment!()
          |> Floki.find("a[data-role^='edit-dashboard-']")
          |> Floki.attribute("href")

        {:ok, Map.put(context, :edit_href, edit_href)}
      end

      then_ "choosing the button opens the chat beside the dashboard", context do
        {:ok, edit_view, _edit_html} = live(context.owner_conn, context.edit_href)
        assert has_element?(edit_view, "[data-role='dashboard-chat-send-btn']")
        {:ok, context}
      end
    end
  end
end
