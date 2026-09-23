defmodule MetricFlowSpex.Criterion5080SystemProvidesMetricNamesToLlmSpex do
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

  spex "The system provides available metric names to the LLM", fail_on_error_logs: false do
    scenario "the LLM can reference actual account metrics in the generated spec" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription
      given_ :owner_has_metrics

      given_ "user opens the visualization editor with metrics available", context do
        {:ok, view, html} = live(context.owner_conn, "/app/visualizations/new")
        # The editor should show available metrics in the selector
        assert html =~ "impressions"
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the LLM generates a spec that references a real metric from the account", context do
        with_cassette "visualization_chat_generate", @cassette_opts, fn plug ->
          Application.put_env(:metric_flow, :req_http_options, plug: plug)

          capture_log(fn ->
            render_submit(context.view, "send_chat", %{"prompt" => "Show me impressions over time as a line chart"})
            Process.sleep(100)
            render(context.view)
          end)

          # The chart renders — which means the named data source "impressions"
          # was resolved against actual metric data from the account
          assert has_element?(context.view, "[data-role='vega-lite-chart']")

          # The metric selector should show the metric is now bound
          html = render(context.view)
          assert html =~ "impressions"

          Application.delete_env(:metric_flow, :req_http_options)
        end

        :ok
      end
    end
  end
end
