defmodule MetricFlowSpex.Criterion800GeneratedSpecLoadsAndRendersSpex do
  use MetricFlowSpex.Case, async: false
  import Phoenix.LiveViewTest
  import ExUnit.CaptureLog

  import MetricFlowSpex.SharedGivens

  spex "Generated spec loads into the editor and renders immediately", criterion: 800 do
    scenario "once the LLM responds, the spec editor and preview update with no further action" do
      given_(:user_logged_in_as_owner)
      given_(:owner_has_active_subscription)
      given_(:owner_has_metrics)

      given_ "user opens the visualization editor and spec panel", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/visualizations/new")

        view
        |> element("[data-role='open-spec-panel']")
        |> render_click()

        {:ok, Map.put(context, :view, view)}
      end

      when_ "the LLM has just generated a spec", context do
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

      then_ "the spec is loaded into the spec editor and the chart renders in the live preview without further action",
            context do
        spec_text =
          context.view
          |> element("[data-role='vega-spec-textarea']")
          |> render()

        assert spec_text =~ "impressions"
        assert has_element?(context.view, "[data-role='vega-lite-chart']")
        {:ok, context}
      end
    end
  end
end
