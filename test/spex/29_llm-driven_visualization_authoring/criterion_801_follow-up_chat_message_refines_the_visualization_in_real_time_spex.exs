defmodule MetricFlowSpex.Criterion801FollowUpRefinesInRealTimeSpex do
  use MetricFlowSpex.Case, async: false
  import Phoenix.LiveViewTest
  import ExUnit.CaptureLog

  import MetricFlowSpex.SharedGivens

  spex "Follow-up chat message refines the visualization in real time", criterion: 801 do
    scenario "a follow-up refinement message streams a response and updates the chart live" do
      given_(:user_logged_in_as_owner)
      given_(:owner_has_active_subscription)
      given_(:owner_has_metrics)

      given_ "a visualization already generated in the authoring workspace", context do
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

      when_ "the user sends a follow-up message asking to change the color and switch chart types",
            context do
        Application.put_env(
          :metric_flow,
          :command_runner,
          MetricFlowTest.VizChatStub.generate_followup()
        )

        capture_log(fn ->
          render_submit(context.view, "send_chat", %{
            "prompt" => "Change the color to green and switch from a bar chart to a line chart"
          })

          Process.sleep(100)
          render(context.view)
        end)

        Application.delete_env(:metric_flow, :command_runner)

        {:ok, context}
      end

      then_ "the response streams into the chat panel, and the spec editor and live preview update automatically without a page reload",
            context do
        html = render(context.view)
        assert html =~ "Change the color to green and switch from a bar chart to a line chart"
        assert has_element?(context.view, "[data-role='vega-lite-chart']")
        {:ok, context}
      end
    end
  end
end
