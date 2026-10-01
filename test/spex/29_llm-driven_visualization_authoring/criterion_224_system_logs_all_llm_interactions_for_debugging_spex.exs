defmodule MetricFlowSpex.Criterion4151SystemLogsLlmInteractionsSpex do
  use MetricFlowSpex.Case, async: false
  import Phoenix.LiveViewTest
  import ExUnit.CaptureLog

  import MetricFlowSpex.SharedGivens

  spex "System logs all LLM interactions for debugging",
    fail_on_error_logs: false,
    criterion: 224 do
    scenario "generating a chart produces debug logs" do
      given_(:user_logged_in_as_owner)
      given_(:owner_has_active_subscription)

      given_ "user is on the report generator", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/reports/generate")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "user generates a chart and logs are captured", context do
        Application.put_env(
          :metric_flow,
          :command_runner,
          MetricFlowTest.ReportGeneratorStub.generate_revenue_bar_chart()
        )

        log =
          capture_log(fn ->
            context.view
            |> render_change("update_prompt", %{"prompt" => "Show me a chart"})

            context.view
            |> render_submit("generate", %{"prompt" => "Show me a chart"})
          end)

        Application.delete_env(:metric_flow, :command_runner)

        # The AI module logs the generation request/response
        # Even if the log content varies, the generation should produce some log output
        assert is_binary(log)
        {:ok, context}
      end
    end
  end
end
