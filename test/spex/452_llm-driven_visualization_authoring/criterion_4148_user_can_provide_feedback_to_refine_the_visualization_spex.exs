defmodule MetricFlowSpex.Criterion4148RefinementFeedbackSpex do
  use SexySpex
  use MetricFlowTest.ConnCase, async: false
  import Phoenix.LiveViewTest
  import ExUnit.CaptureLog
  import ReqCassette

  import_givens MetricFlowSpex.SharedGivens

  @cassette_opts [
    cassette_dir: "test/cassettes/ai",
    filter_request_headers: ["x-api-key", "authorization"],
    mode: :replay,
    match_requests_on: [:method, :uri]
  ]

  spex "User can provide feedback to refine the visualization", fail_on_error_logs: false do
    scenario "after generating a chart, user can submit a new prompt to refine it" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "user is on the report generator", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/reports/generate")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "user generates a chart, refines it, and the chart updates", context do
        with_cassette "report_generator_success", @cassette_opts, fn plug ->
          Application.put_env(:metric_flow, :req_http_options, plug: plug)

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

          Application.delete_env(:metric_flow, :req_http_options)
        end

        :ok
      end
    end
  end
end
