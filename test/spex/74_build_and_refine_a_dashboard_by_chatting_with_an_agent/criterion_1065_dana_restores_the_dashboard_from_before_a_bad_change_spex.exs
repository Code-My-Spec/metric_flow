defmodule MetricFlowSpex.Story74.Criterion1065Spex do
  @moduledoc """
  Story 74 — Build and Refine a Dashboard by Chatting with an Agent
  Criterion 1065 — Dana restores the dashboard from before a bad
  change: opening previous versions and restoring an earlier one shows
  that version's content, and the restore itself appears as a new
  version.
  """

  use MetricFlowSpex.Case, async: false

  import MetricFlowSpex.SharedGivens

  spex "Dana restores the dashboard from before a bad change", criterion: 1065 do
    scenario "restoring the middle of three versions shows that version and adds a new one" do
      given_(:user_logged_in_as_owner)
      given_(:owner_has_metrics)

      given_ "the agent has changed Dana's dashboard three times", context do
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

        Application.put_env(
          :metric_flow,
          :command_runner,
          MetricFlowTest.DashboardBuilderStub.refine_to_area_chart()
        )

        render_submit(view, "send_dashboard_chat", %{"message" => "Change it to an area chart"})
        await_dashboard_chat_completion(view)
        Application.delete_env(:metric_flow, :command_runner)

        {:ok, Map.put(context, :view, view)}
      end

      when_ "she opens previous versions and restores the second one", context do
        rows =
          context.view
          |> render()
          |> Floki.parse_fragment!()
          |> Floki.find("[data-role='dashboard-version']")

        second_row = Enum.at(rows, 1)
        [restore_id] = second_row |> Floki.find("button") |> Floki.attribute("phx-value-id")

        render_click(context.view, "restore_version", %{"id" => restore_id})
        {:ok, context}
      end

      then_ "the dashboard shows what it looked like at that version", context do
        html = render(context.view)

        cards =
          html
          |> Floki.parse_fragment!()
          |> Floki.find("[data-role='visualization-card']")

        assert length(cards) == 3
        refute html =~ ~s(badge-ghost badge-sm">area<)
        {:ok, context}
      end

      then_ "the restore appears as a new version in the list", context do
        rows =
          context.view
          |> render()
          |> Floki.parse_fragment!()
          |> Floki.find("[data-role='dashboard-version']")

        assert length(rows) == 4
        {:ok, context}
      end
    end
  end
end
