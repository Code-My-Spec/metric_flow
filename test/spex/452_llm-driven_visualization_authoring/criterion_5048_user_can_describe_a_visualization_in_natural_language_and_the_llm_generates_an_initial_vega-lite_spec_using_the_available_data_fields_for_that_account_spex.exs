defmodule MetricFlowSpex.Criterion5048NaturalLanguageGeneratesSpecSpex do
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

  spex "User describes a visualization and LLM generates a Vega-Lite spec", fail_on_error_logs: false do
    scenario "submitting a chat prompt on the editor workspace generates a chart" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription
      given_ :owner_has_metrics

      given_ "user opens the visualization editor and chat panel", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/visualizations/new")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "user sends a chat message and a Vega-Lite chart is rendered", context do
        with_cassette "visualization_chat_generate", @cassette_opts, fn plug ->
          Application.put_env(:metric_flow, :req_http_options, plug: plug)

          capture_log(fn ->
            render_submit(context.view, "send_chat", %{"prompt" => "Show me impressions over time as a line chart"})
            Process.sleep(100)
            render(context.view)
          end)

          html = render(context.view)
          assert has_element?(context.view, "[data-role='vega-lite-chart']")
          assert html =~ "data-spec="

          Application.delete_env(:metric_flow, :req_http_options)
        end

        :ok
      end
    end
  end
end
