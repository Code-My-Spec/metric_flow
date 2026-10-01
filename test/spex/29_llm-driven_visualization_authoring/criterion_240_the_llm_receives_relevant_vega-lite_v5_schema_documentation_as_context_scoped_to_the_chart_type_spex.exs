defmodule MetricFlowSpex.Criterion240LlmReceivesChartTypeScopedSchemaDocsSpex do
  use MetricFlowSpex.Case, async: false
  import Phoenix.LiveViewTest
  import ExUnit.CaptureLog

  import MetricFlowSpex.SharedGivens

  spex "The LLM receives relevant Vega-Lite v5 schema documentation as context, scoped to the chart type being requested, so it can produce valid specs for advanced chart types",
    criterion: 240 do
    scenario "requesting an advanced chart type produces a valid rendered spec" do
      given_(:user_logged_in_as_owner)
      given_(:owner_has_active_subscription)
      given_(:owner_has_metrics)

      given_ "user opens the visualization editor", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/visualizations/new")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user requests an advanced chart type such as a Gantt chart", context do
        Application.put_env(
          :metric_flow,
          :command_runner,
          MetricFlowTest.VizChatStub.generate_initial()
        )

        capture_log(fn ->
          render_submit(context.view, "send_chat", %{
            "prompt" => "Show me a Gantt chart of my campaign schedule"
          })

          Process.sleep(100)
          render(context.view)
        end)

        Application.delete_env(:metric_flow, :command_runner)

        {:ok, context}
      end

      then_ "a valid Vega-Lite spec for the requested chart type is produced", context do
        assert has_element?(context.view, "[data-role='vega-lite-chart']")
        {:ok, context}
      end
    end
  end
end
