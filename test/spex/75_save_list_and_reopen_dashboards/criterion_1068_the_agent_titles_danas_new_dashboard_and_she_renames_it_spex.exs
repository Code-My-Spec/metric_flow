defmodule MetricFlowSpex.Story75.Criterion1068Spex do
  @moduledoc """
  Story 75 — Save, List and Reopen Dashboards
  Criterion 1068 — The agent titles Dana's new dashboard from her request,
  and she can rename it from the list or the builder.
  """

  use MetricFlowSpex.Case, async: false

  import MetricFlowSpex.SharedGivens

  spex "The agent titles Dana's new dashboard and she renames it", criterion: 1068 do
    scenario "the draft gets a title from her request, and she renames it from the list" do
      given_(:user_logged_in_as_owner)
      given_(:owner_has_metrics)

      given_ "Dana opens a new dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, ~p"/app/dashboards/new")
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
          "message" => "Show me traffic over the last 30 days"
        })

        Process.sleep(100)
        Application.delete_env(:metric_flow, :command_runner)

        {:ok, context}
      end

      then_ "the dashboard has a title drawn from her request", context do
        {:ok, _index_view, index_html} = live(context.owner_conn, ~p"/app/dashboards")
        assert index_html =~ "traffic"
        {:ok, context}
      end

      then_ "she can rename it to 'Monday review' from the list", context do
        {:ok, index_view, index_html} = live(context.owner_conn, ~p"/app/dashboards")

        [rename_id] =
          index_html
          |> Floki.parse_fragment!()
          |> Floki.find("[data-role^='rename-dashboard-']")
          |> Floki.attribute("phx-value-id")

        index_view
        |> element("[data-role='rename-dashboard-#{rename_id}']")
        |> render_click()

        index_view
        |> form("[data-role='rename-form-#{rename_id}'] form", %{"name" => "Monday review"})
        |> render_submit()

        assert render(index_view) =~ "Monday review"
        {:ok, context}
      end
    end
  end
end
