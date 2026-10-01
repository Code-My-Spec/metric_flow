defmodule MetricFlowSpex.Criterion4147PreviewGeneratedVisualizationSpex do
  use MetricFlowSpex.Case, async: false
  import Phoenix.LiveViewTest
  import ExUnit.CaptureLog

  import MetricFlowSpex.SharedGivens

  spex "User can preview generated visualization", fail_on_error_logs: false, criterion: 220 do
    scenario "chart preview section appears after generation" do
      given_(:user_logged_in_as_owner)
      given_(:owner_has_active_subscription)

      given_ "user is on the report generator", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/reports/generate")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "user generates a chart and a preview section with the rendered chart is visible",
            context do
        Application.put_env(
          :metric_flow,
          :command_runner,
          MetricFlowTest.ReportGeneratorStub.generate_revenue_bar_chart()
        )

        capture_log(fn ->
          context.view
          |> render_change("update_prompt", %{"prompt" => "Show me impressions over time"})

          context.view
          |> render_submit("generate", %{"prompt" => "Show me impressions over time"})
        end)

        html = render(context.view)
        assert has_element?(context.view, "[data-role='chart-preview-section']")
        assert has_element?(context.view, "[data-role='vega-lite-chart']")
        assert html =~ "data-spec="

        Application.delete_env(:metric_flow, :command_runner)

        {:ok, context}
      end
    end
  end
end
