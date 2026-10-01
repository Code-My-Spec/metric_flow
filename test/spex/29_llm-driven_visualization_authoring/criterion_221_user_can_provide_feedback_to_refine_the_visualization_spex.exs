defmodule MetricFlowSpex.Criterion4148RefinementFeedbackSpex do
  use MetricFlowSpex.Case, async: false
  import Phoenix.LiveViewTest
  import ExUnit.CaptureLog

  import MetricFlowSpex.SharedGivens

  spex "User can provide feedback to refine the visualization",
    fail_on_error_logs: false,
    criterion: 221 do
    scenario "after generating a chart, user can submit a new prompt to refine it" do
      given_(:user_logged_in_as_owner)
      given_(:owner_has_active_subscription)

      given_ "user is on the report generator", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/reports/generate")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "user generates a chart, refines it, and the chart updates", context do
        Application.put_env(
          :metric_flow,
          :command_runner,
          MetricFlowTest.ReportGeneratorStub.generate_then_refine()
        )

        # Initial generation
        capture_log(fn ->
          context.view
          |> render_change("update_prompt", %{"prompt" => "Show me impressions"})

          context.view
          |> render_submit("generate", %{"prompt" => "Show me impressions"})
        end)

        assert has_element?(context.view, "[data-role='prompt-input']")
        assert has_element?(context.view, "[data-role='generate-btn']")

        # Refinement
        capture_log(fn ->
          context.view
          |> render_change("update_prompt", %{"prompt" => "Make it a bar chart instead"})

          context.view
          |> render_submit("generate", %{"prompt" => "Make it a bar chart instead"})
        end)

        assert has_element?(context.view, "[data-role='vega-lite-chart']")

        Application.delete_env(:metric_flow, :command_runner)

        {:ok, context}
      end
    end
  end
end
