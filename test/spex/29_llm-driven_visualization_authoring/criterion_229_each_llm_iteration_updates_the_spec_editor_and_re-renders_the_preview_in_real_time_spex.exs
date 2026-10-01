defmodule MetricFlowSpex.Criterion5051EachIterationUpdatesPreviewSpex do
  use MetricFlowSpex.Case, async: false
  import Phoenix.LiveViewTest
  import ExUnit.CaptureLog

  import MetricFlowSpex.SharedGivens

  spex "Each LLM iteration updates the spec editor and re-renders the preview",
    fail_on_error_logs: false,
    criterion: 229 do
    scenario "the spec editor content changes after each LLM generation" do
      given_(:user_logged_in_as_owner)
      given_(:owner_has_active_subscription)
      given_(:owner_has_metrics)

      given_ "user opens the visualization editor with spec panel open", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/visualizations/new")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "each chat message updates both the spec editor and the chart preview", context do
        Application.put_env(
          :metric_flow,
          :command_runner,
          MetricFlowTest.VizChatStub.generate_then_followup()
        )

        # First generation
        capture_log(fn ->
          render_submit(context.view, "send_chat", %{
            "prompt" => "Show me impressions over time as a line chart"
          })

          Process.sleep(100)
          render(context.view)
        end)

        # Open spec panel to inspect the spec
        context.view |> element("[data-role='open-spec-panel']") |> render_click()
        first_spec_html = render(context.view)
        assert first_spec_html =~ "impressions"
        assert has_element?(context.view, "[data-role='vega-lite-chart']")

        # Second generation
        capture_log(fn ->
          render_submit(context.view, "send_chat", %{
            "prompt" => "Now add clicks as a second series and make it a layered chart"
          })

          Process.sleep(100)
          render(context.view)
        end)

        second_spec_html = render(context.view)
        assert second_spec_html =~ "clicks"
        assert has_element?(context.view, "[data-role='vega-lite-chart']")

        Application.delete_env(:metric_flow, :command_runner)

        {:ok, context}
      end
    end
  end
end
