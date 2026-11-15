defmodule MetricFlowSpex.Story74.Criterion1064Spex do
  @moduledoc """
  Story 74 — Build and Refine a Dashboard by Chatting with an Agent
  Criterion 1064 — A model error leaves Dana's dashboard unchanged: the
  chat shows a clear error, the dashboard is unchanged, and she can
  retry.
  """

  use MetricFlowSpex.Case, async: false

  import MetricFlowSpex.SharedGivens

  spex "A model error leaves Dana's dashboard unchanged",
    fail_on_error_logs: false,
    criterion: 1064 do
    scenario "a failed agent turn errors in the chat without touching the dashboard" do
      given_(:user_logged_in_as_owner)
      given_(:owner_has_metrics)

      given_ "Dana has a dashboard showing traffic and spend", context do
        {:ok, view, _html} = live(context.owner_conn, ~p"/app/dashboards/new")

        Application.put_env(
          :metric_flow,
          :command_runner,
          MetricFlowTest.DashboardBuilderStub.generate_initial()
        )

        render_submit(view, "send_dashboard_chat", %{"message" => "Show me impressions"})
        await_dashboard_chat_completion(view)
        Application.delete_env(:metric_flow, :command_runner)

        original_cards =
          view
          |> render()
          |> Floki.parse_fragment!()
          |> Floki.find("[data-role='visualization-card']")
          |> length()

        {:ok, Map.merge(context, %{view: view, original_card_count: original_cards})}
      end

      when_ "she asks for a change and the agent fails", context do
        Application.put_env(
          :metric_flow,
          :command_runner,
          MetricFlowTest.ClaudeCodeStub.error("model unavailable")
        )

        render_submit(context.view, "send_dashboard_chat", %{
          "message" => "Add a bar chart of clicks"
        })

        await_dashboard_chat_completion(context.view)
        Application.delete_env(:metric_flow, :command_runner)

        {:ok, context}
      end

      then_ "the chat shows a clear error", context do
        assert has_element?(context.view, "[data-role='dashboard-chat-error']")
        {:ok, context}
      end

      then_ "the dashboard is unchanged", context do
        cards =
          context.view
          |> render()
          |> Floki.parse_fragment!()
          |> Floki.find("[data-role='visualization-card']")

        assert length(cards) == context.original_card_count
        {:ok, context}
      end

      then_ "she can retry the request", context do
        assert has_element?(context.view, "[data-role='dashboard-chat-send-btn']:not([disabled])")
        {:ok, context}
      end
    end
  end
end
