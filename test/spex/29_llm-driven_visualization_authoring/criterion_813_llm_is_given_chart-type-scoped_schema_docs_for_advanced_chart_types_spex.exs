defmodule MetricFlowSpex.Criterion813LlmGivenChartTypeScopedSchemaDocsSpex do
  use MetricFlowSpex.Case, async: false
  import Phoenix.LiveViewTest
  import ExUnit.CaptureLog

  import MetricFlowSpex.SharedGivens

  spex "LLM is given chart-type-scoped schema docs for advanced chart types", criterion: 813 do
    scenario "requesting a Gantt chart produces a valid spec for that chart type" do
      given_(:user_logged_in_as_owner)
      given_(:owner_has_active_subscription)
      given_(:owner_has_metrics)

      given_ "a user requests an advanced chart type such as a Gantt chart", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/visualizations/new")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the LLM generates the spec", context do
        Application.put_env(
          :metric_flow,
          :command_runner,
          MetricFlowTest.VizChatStub.generate_initial()
        )

        capture_log(fn ->
          render_submit(context.view, "send_chat", %{
            "prompt" => "Show me a Gantt chart of my campaign timeline"
          })

          Process.sleep(100)
          render(context.view)
        end)

        Application.delete_env(:metric_flow, :command_runner)

        {:ok, context}
      end

      then_ "it is given Vega-Lite v5 schema documentation scoped to that chart type, and produces a valid spec for it",
            context do
        assert has_element?(context.view, "[data-role='vega-lite-chart']")
        {:ok, context}
      end
    end
  end
end
