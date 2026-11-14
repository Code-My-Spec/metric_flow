defmodule MetricFlowSpex.Story74.Criterion1059Spex do
  @moduledoc """
  Story 74 — Build and Refine a Dashboard by Chatting with an Agent
  Criterion 1059 — Dana's first request creates a draft dashboard: the
  agent's first build is saved with no explicit Save, and the same
  dashboard is still there on reload.
  """

  use MetricFlowSpex.Case, async: false

  import MetricFlowSpex.SharedGivens

  spex "Dana's first chat request creates a draft dashboard", criterion: 1059 do
    scenario "the agent's first build is already saved when the dashboard is reopened" do
      given_(:user_logged_in_as_owner)
      given_(:owner_has_metrics)

      given_ "Dana opens a new dashboard and has not built anything", context do
        {:ok, view, html} = live(context.owner_conn, ~p"/app/dashboards/new")
        refute html =~ "data-role=\"visualization-card\""
        {:ok, Map.put(context, :view, view)}
      end

      when_ "she asks the agent for traffic and spend over the last 30 days and it builds",
            context do
        Application.put_env(
          :metric_flow,
          :command_runner,
          MetricFlowTest.DashboardBuilderStub.generate_initial()
        )

        render_submit(context.view, "send_dashboard_chat", %{
          "message" => "Show me traffic and spend over the last 30 days"
        })

        Process.sleep(100)
        Application.delete_env(:metric_flow, :command_runner)

        {:ok, context}
      end

      then_ "a dashboard record exists as a draft, listed on the dashboards page", context do
        {:ok, _index_view, index_html} = live(context.owner_conn, ~p"/app/dashboards")
        assert index_html =~ "data-role=\"dashboard-card\""
        {:ok, context}
      end

      then_ "refreshing the page shows the same dashboard", context do
        {:ok, _index_view, index_html} = live(context.owner_conn, ~p"/app/dashboards")

        [edit_href | _] =
          index_html
          |> Floki.parse_fragment!()
          |> Floki.find("a[data-role^='edit-dashboard-']")
          |> Floki.attribute("href")

        {:ok, reopened_view, reopened_html} = live(context.owner_conn, edit_href)
        assert has_element?(reopened_view, "[data-role='visualization-card']")
        assert reopened_html =~ "Total Impressions"
        {:ok, context}
      end
    end
  end
end
