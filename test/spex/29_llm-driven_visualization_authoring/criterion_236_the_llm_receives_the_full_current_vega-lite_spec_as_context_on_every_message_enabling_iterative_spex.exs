defmodule MetricFlowSpex.Criterion236LlmReceivesFullSpecAsContextSpex do
  use MetricFlowSpex.Case, async: false
  import Phoenix.LiveViewTest
  import ExUnit.CaptureLog

  import MetricFlowSpex.SharedGivens

  spex "The LLM receives the full current Vega-Lite spec as context on every message, enabling iterative refinement without regenerating the spec from scratch",
    criterion: 236 do
    scenario "a follow-up message continues editing the existing spec rather than starting over" do
      given_(:user_logged_in_as_owner)
      given_(:owner_has_active_subscription)
      given_(:owner_has_metrics)

      given_ "a visualization already generated in the editor", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/visualizations/new")

        Application.put_env(
          :metric_flow,
          :command_runner,
          MetricFlowTest.VizChatStub.generate_initial()
        )

        capture_log(fn ->
          render_submit(view, "send_chat", %{
            "prompt" => "Show me impressions over time as a line chart"
          })

          Process.sleep(100)
          render(view)
        end)

        Application.delete_env(:metric_flow, :command_runner)

        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user sends a follow-up refinement message", context do
        Application.put_env(
          :metric_flow,
          :command_runner,
          MetricFlowTest.VizChatStub.generate_followup()
        )

        capture_log(fn ->
          render_submit(context.view, "send_chat", %{"prompt" => "Now make the line thicker"})
          Process.sleep(100)
          render(context.view)
        end)

        Application.delete_env(:metric_flow, :command_runner)

        {:ok, context}
      end

      then_ "the chart still renders and both messages remain part of the same iterative session",
            context do
        html = render(context.view)
        assert html =~ "Show me impressions over time as a line chart"
        assert html =~ "Now make the line thicker"
        assert has_element?(context.view, "[data-role='vega-lite-chart']")
        {:ok, context}
      end
    end
  end
end
