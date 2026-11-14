defmodule MetricFlowSpex.Story75.Criterion1074Spex do
  @moduledoc """
  Story 75 — Save, List and Reopen Dashboards
  Criterion 1074 — A search that matches none of Dana's dashboards shows
  an empty result.
  """

  use MetricFlowSpex.Case, async: false

  import MetricFlowSpex.SharedGivens

  spex "Dana searches for a dashboard that does not exist", criterion: 1074 do
    scenario "a search with no matches shows an empty result, not an error" do
      given_(:user_logged_in_as_owner)
      given_(:owner_has_metrics)

      given_ "Dana has three dashboards", context do
        for _ <- 1..3 do
          {:ok, view, _html} = live(context.owner_conn, ~p"/app/dashboards/new")

          Application.put_env(
            :metric_flow,
            :command_runner,
            MetricFlowTest.DashboardBuilderStub.generate_initial()
          )

          render_submit(view, "send_dashboard_chat", %{"message" => "Show me impressions"})
          Process.sleep(100)
          Application.delete_env(:metric_flow, :command_runner)
        end

        {:ok, index_view, _html} = live(context.owner_conn, ~p"/app/dashboards")
        {:ok, Map.put(context, :index_view, index_view)}
      end

      when_ "she searches for 'payroll'", context do
        context.index_view
        |> form("[data-role='dashboard-search'] form", %{"query" => "payroll"})
        |> render_change()

        {:ok, context}
      end

      then_ "the list shows an empty result with no dashboards", context do
        assert has_element?(context.index_view, "[data-role='empty-search-results']")

        cards =
          render(context.index_view)
          |> Floki.parse_fragment!()
          |> Floki.find("[data-role='user-dashboards'] [data-role='dashboard-card']")

        assert cards == []
        {:ok, context}
      end
    end
  end
end
