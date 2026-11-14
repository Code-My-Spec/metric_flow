defmodule MetricFlowSpex.Story74.Criterion1066Spex do
  @moduledoc """
  Story 74 — Build and Refine a Dashboard by Chatting with an Agent
  Criterion 1066 — Dana narrows to 90 days and the filter is still
  there on reopen: the chosen date range survives a fresh mount.
  """

  use MetricFlowSpex.Case, async: false

  import MetricFlowSpex.SharedGivens

  spex "Dana narrows to 90 days and the filter is still there on reopen", criterion: 1066 do
    scenario "the chosen date range persists across a fresh mount" do
      given_(:user_logged_in_as_owner)
      given_(:owner_has_metrics)

      given_ "Dana asked the agent for a dashboard with a date range filter", context do
        {:ok, view, _html} = live(context.owner_conn, ~p"/app/dashboards/new")

        Application.put_env(
          :metric_flow,
          :command_runner,
          MetricFlowTest.DashboardBuilderStub.generate_initial()
        )

        render_submit(view, "send_dashboard_chat", %{"message" => "Show me impressions"})
        Process.sleep(100)
        Application.delete_env(:metric_flow, :command_runner)

        assert has_element?(view, "[data-role='filter-control'] form[phx-change]")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "she sets the filter to the last 90 days and leaves", context do
        context.view
        |> element("[data-role='filter-control'] form[phx-change]")
        |> render_change(%{"range" => "90"})

        {:ok, context}
      end

      then_ "she reopens the dashboard later and the filter still shows the last 90 days",
            context do
        {:ok, _index_view, index_html} = live(context.owner_conn, ~p"/app/dashboards")

        [edit_href | _] =
          index_html
          |> Floki.parse_fragment!()
          |> Floki.find("a[data-role^='edit-dashboard-']")
          |> Floki.attribute("href")

        {:ok, _reopened_view, reopened_html} = live(context.owner_conn, edit_href)
        assert reopened_html =~ ~s(value="90" selected)
        {:ok, context}
      end
    end
  end
end
