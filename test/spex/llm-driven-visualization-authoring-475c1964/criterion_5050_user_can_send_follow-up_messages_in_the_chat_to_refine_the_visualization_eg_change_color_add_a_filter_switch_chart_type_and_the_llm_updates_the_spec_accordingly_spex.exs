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
    scenario "a second chat message updates the chart spec" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription
      given_ :owner_has_metrics

      given_ "user opens the visualization editor", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/visualizations/new")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "user sends two messages and the chart updates each time", context do
        with_cassette "visualization_chat_generate", @cassette_opts, fn plug ->
          Application.put_env(:metric_flow, :req_http_options, plug: plug)

          # First message — generates initial chart (async task)
          capture_log(fn ->
            render_submit(context.view, "send_chat", %{"prompt" => "Show me impressions over time as a line chart"})
            # Flush the LiveView mailbox so it processes the Task result
            Process.sleep(100)
            render(context.view)
          end)

          assert has_element?(context.view, "[data-role='vega-lite-chart']")
          first_html = render(context.view)

          # Second message — refines the chart (multi-turn with chat history)
          capture_log(fn ->
            render_submit(context.view, "send_chat", %{"prompt" => "Now add clicks as a second series and make it a layered chart"})
            Process.sleep(100)
            render(context.view)
          end)

          second_html = render(context.view)

          # Must not show an error — proves multi-turn chat history works
          refute has_element?(context.view, "[data-role='chat-error']")

          # Chart should still be present and spec should have changed
          assert has_element?(context.view, "[data-role='vega-lite-chart']")
          refute first_html == second_html

          Application.delete_env(:metric_flow, :req_http_options)
        end

        :ok
      end
    end
  end
end
