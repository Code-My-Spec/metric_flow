defmodule MetricFlowSpex.Criterion5054NameAndSaveVisualizationSpex do
  use MetricFlowSpex.Case, async: false
  import Phoenix.LiveViewTest
  import ExUnit.CaptureLog

  import MetricFlowSpex.SharedGivens

  spex "User can name and save the visualization for inclusion in reports",
    fail_on_error_logs: false,
    criterion: 232 do
    scenario "save section appears after generation with name input" do
      given_(:user_logged_in_as_owner)
      given_(:owner_has_active_subscription)

      given_ "user is on the report generator", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/reports/generate")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "user generates a chart and a save section is displayed", context do
        Application.put_env(
          :metric_flow,
          :command_runner,
          MetricFlowTest.ReportGeneratorStub.generate_revenue_bar_chart()
        )

        capture_log(fn ->
          context.view
          |> render_change("update_prompt", %{"prompt" => "Show me a chart"})

          context.view
          |> render_submit("generate", %{"prompt" => "Show me a chart"})
        end)

        assert has_element?(context.view, "[data-role='save-section']")
        assert has_element?(context.view, "[data-role='save-name-input']")
        assert has_element?(context.view, "[data-role='save-visualization-btn']")

        Application.delete_env(:metric_flow, :command_runner)

        {:ok, context}
      end
    end

    scenario "saving with a blank name shows an error" do
      given_(:user_logged_in_as_owner)
      given_(:owner_has_active_subscription)

      given_ "user is on the report generator", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/reports/generate")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "user generates a chart and tries to save without a name", context do
        Application.put_env(
          :metric_flow,
          :command_runner,
          MetricFlowTest.ReportGeneratorStub.generate_revenue_bar_chart()
        )

        capture_log(fn ->
          context.view
          |> render_change("update_prompt", %{"prompt" => "Show me a chart"})

          context.view
          |> render_submit("generate", %{"prompt" => "Show me a chart"})
        end)

        context.view
        |> render_change("update_save_name", %{"save_name" => ""})

        context.view
        |> render_submit("save_visualization", %{"save_name" => ""})

        assert has_element?(context.view, "[data-role='save-error']")
        html = render(context.view)
        assert html =~ "required" || html =~ "Name"

        Application.delete_env(:metric_flow, :command_runner)

        {:ok, context}
      end
    end
  end
end
