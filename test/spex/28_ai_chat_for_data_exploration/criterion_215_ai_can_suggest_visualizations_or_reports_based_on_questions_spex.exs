defmodule MetricFlowSpex.Criterion215AiCanSuggestVisualizationsOrReportsBasedOnQuestionsSpex do
  use MetricFlowSpex.Case, async: false
  import Phoenix.LiveViewTest
  import ExUnit.CaptureLog

  import MetricFlowSpex.SharedGivens

  alias MetricFlowTest.ClaudeCodeStub

  spex "AI can suggest visualizations or reports based on questions", criterion: 215 do
    scenario "a user asks a question best answered visually" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription
      given_ :owner_has_metrics

      given_ "a user viewing the AI chat", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/chat")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the AI responds to a question best answered visually", context do
        Application.put_env(
          :metric_flow,
          :test_llm_options,
          command_runner:
            ClaudeCodeStub.text(
              "Here's how your clicks have trended over the last month: a steady upward trend with " <>
                "a brief dip mid-month."
            )
        )

        capture_log(fn ->
          context.view
          |> form("form[phx-submit='send_message']", %{
            "content" => "Show me how my clicks have trended over the last month"
          })
          |> render_submit()

          Process.sleep(100)
          render(context.view)
        end)

        Application.delete_env(:metric_flow, :test_llm_options)

        {:ok, context}
      end

      then_ "it suggests a relevant visualization or report", context do
        assert has_element?(context.view, "[data-role='suggested-visualization']"),
               "Expected the AI's response to include a suggested visualization or report"

        {:ok, context}
      end
    end
  end
end
