defmodule MetricFlowSpex.Criterion810LlmEditsExistingSpecSpex do
  use MetricFlowSpex.Case, async: false
  import Phoenix.LiveViewTest
  import ExUnit.CaptureLog

  import MetricFlowSpex.SharedGivens

  spex "LLM edits the existing spec rather than regenerating from scratch", criterion: 810 do
    scenario "a follow-up refinement continues editing the current spec" do
      given_(:user_logged_in_as_owner)
      given_(:owner_has_active_subscription)
      given_(:owner_has_metrics)

      given_ "a visualization already has a current Vega-Lite spec", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/visualizations/new")

        view
        |> element("[data-role='open-spec-panel']")
        |> render_click()

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
          render_submit(context.view, "send_chat", %{"prompt" => "Make the line thicker"})
          Process.sleep(100)
          render(context.view)
        end)

        Application.delete_env(:metric_flow, :command_runner)

        {:ok, context}
      end

      then_ "the LLM is given the full current spec as context and edits it, rather than generating an unrelated new spec",
            context do
        spec_text =
          context.view
          |> element("[data-role='vega-spec-textarea']")
          |> render()

        assert spec_text =~ "impressions"
        {:ok, context}
      end
    end
  end
end
