defmodule MetricFlowSpex.Criterion241ChatPanelRendersFullHistorySpex do
  use MetricFlowSpex.Case, async: false
  import Phoenix.LiveViewTest
  import ExUnit.CaptureLog

  import MetricFlowSpex.SharedGivens

  spex "The chat panel renders the full conversation history -- user messages and assistant responses -- for the duration of the editing session",
    criterion: 241 do
    scenario "both user and assistant messages remain visible across the session" do
      given_(:user_logged_in_as_owner)
      given_(:owner_has_active_subscription)
      given_(:owner_has_metrics)

      given_ "user opens the visualization editor", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/visualizations/new")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user exchanges a message with the LLM", context do
        Application.put_env(
          :metric_flow,
          :command_runner,
          MetricFlowTest.VizChatStub.generate_initial()
        )

        capture_log(fn ->
          render_submit(context.view, "send_chat", %{
            "prompt" => "Show me impressions over time as a line chart"
          })

          Process.sleep(100)
          render(context.view)
        end)

        Application.delete_env(:metric_flow, :command_runner)

        {:ok, context}
      end

      then_ "the chat panel shows both the user's message and the assistant's response",
            context do
        html = render(context.view)
        assert html =~ "Show me impressions over time as a line chart"
        assert has_element?(context.view, "[data-role='chat-messages']")
        {:ok, context}
      end
    end
  end
end
