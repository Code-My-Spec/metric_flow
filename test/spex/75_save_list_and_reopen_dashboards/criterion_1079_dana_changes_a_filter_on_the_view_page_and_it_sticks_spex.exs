defmodule MetricFlowSpex.Story75.Criterion1079Spex do
  @moduledoc """
  Story 75 — Save, List and Reopen Dashboards
  Criterion 1079 — On the view page Dana can change a dashboard's
  filter controls without opening the chat, and the value she leaves is
  saved with the dashboard.
  """

  use MetricFlowSpex.Case, async: false

  import MetricFlowSpex.SharedGivens

  spex "Dana changes a filter on the view page and it sticks", criterion: 1079 do
    scenario "changing the range on the view page persists across a fresh mount" do
      given_(:user_logged_in_as_owner)
      given_(:owner_has_metrics)

      given_ "Dana's dashboard has a date range filter set to 30 days", context do
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

        {:ok, show_view, _show_html} = live(context.owner_conn, view_href)

        assert has_element?(
                 show_view,
                 "[data-role='filter-control'] option[value='30'][selected]"
               )

        {:ok, Map.merge(context, %{show_view: show_view, view_href: view_href})}
      end

      when_ "she changes it to 90 days on the view page without opening the chat", context do
        context.show_view
        |> element("[data-role='filter-control'] form[phx-change]")
        |> render_change(%{"range" => "90"})

        {:ok, context}
      end

      then_ "she leaves and comes back, and the dashboard still shows 90 days", context do
        {:ok, reopened_view, _html} = live(context.owner_conn, context.view_href)

        assert has_element?(
                 reopened_view,
                 "[data-role='filter-control'] option[value='90'][selected]"
               )

        {:ok, context}
      end
    end
  end
end
