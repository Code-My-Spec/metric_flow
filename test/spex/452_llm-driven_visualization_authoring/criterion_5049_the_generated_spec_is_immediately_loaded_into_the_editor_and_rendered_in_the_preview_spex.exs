defmodule MetricFlowSpex.Criterion5049SpecLoadedIntoEditorAndPreviewSpex do
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

  spex "Generated spec is immediately loaded and rendered in preview", fail_on_error_logs: false do
    scenario "after generation, chart preview and spec are both available" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "user is on the report generator", context do
        {:ok, view, _html} = live(context.owner_conn, "/reports/generate")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "user generates a chart and it is visible in the preview", context do
        with_cassette "report_generator_success", @cassette_opts, fn plug ->
          Application.put_env(:metric_flow, :req_http_options, plug: plug)

          capture_log(fn ->
            context.view
            |> render_change("update_prompt", %{"prompt" => "Show me clicks by day"})

            context.view
            |> render_submit("generate", %{"prompt" => "Show me clicks by day"})
          end)

          assert has_element?(context.view, "[data-role='chart-preview-section']")
          assert has_element?(context.view, "[data-role='vega-lite-chart'][phx-hook='VegaLite']")
          refute has_element?(context.view, "[data-role='empty-state']")

          Application.delete_env(:metric_flow, :req_http_options)
        end

        :ok
      end
    end
  end
end
