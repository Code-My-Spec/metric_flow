defmodule MetricFlowSpex.Criterion5050FollowUpMessagesRefineVizSpex do
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

  spex "User can send follow-up messages to refine the visualization", fail_on_error_logs: false do
    scenario "submitting a second prompt regenerates the chart" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "user is on the report generator", context do
        {:ok, view, _html} = live(context.owner_conn, "/reports/generate")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "user generates a chart, sends follow-up, and chart updates", context do
        with_cassette "report_generator_success", @cassette_opts, fn plug ->
          Application.put_env(:metric_flow, :req_http_options, plug: plug)

          # Initial generation
          capture_log(fn ->
            context.view
            |> render_change("update_prompt", %{"prompt" => "Show me impressions"})

            context.view
            |> render_submit("generate", %{"prompt" => "Show me impressions"})
          end)

          # Follow-up refinement
          capture_log(fn ->
            context.view
            |> render_change("update_prompt", %{"prompt" => "Change it to red bars"})

            context.view
            |> render_submit("generate", %{"prompt" => "Change it to red bars"})
          end)

          assert has_element?(context.view, "[data-role='vega-lite-chart']")

          Application.delete_env(:metric_flow, :req_http_options)
        end

        :ok
      end
    end
  end
end
