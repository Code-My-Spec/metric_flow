defmodule MetricFlowSpex.Criterion805LlmInteractionsLoggedSpex do
  use MetricFlowSpex.Case, async: false
  import Phoenix.LiveViewTest
  import ExUnit.CaptureLog

  import MetricFlowSpex.SharedGivens

  spex "LLM interactions are logged for debugging", criterion: 805 do
    scenario "a successful chat exchange with the LLM produces a debug log entry" do
      given_(:user_logged_in_as_owner)
      given_(:owner_has_active_subscription)
      given_(:owner_has_metrics)

      given_ "a user is exchanging messages with the LLM during an authoring session", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/visualizations/new")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "each message is sent and each response is received", context do
        Application.put_env(
          :metric_flow,
          :command_runner,
          MetricFlowTest.VizChatStub.generate_initial()
        )

        log =
          capture_log(fn ->
            render_submit(context.view, "send_chat", %{
              "prompt" => "Show me impressions over time as a line chart"
            })

            Process.sleep(100)
            render(context.view)
          end)

        Application.delete_env(:metric_flow, :command_runner)

        {:ok, Map.put(context, :log, log)}
      end

      then_ "the interaction is logged for debugging", context do
        assert context.log =~ "viz_chat",
               "Expected the successful chat exchange to be logged for debugging, got: #{context.log}"

        {:ok, context}
      end
    end
  end
end
