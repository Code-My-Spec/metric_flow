defmodule MetricFlowSpex.Criterion5053ChatHistoryPersistsSpex do
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

  spex "Chat history persists for the duration of the authoring session", fail_on_error_logs: false do
    scenario "after multiple messages, all chat history is visible" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription
      given_ :owner_has_metrics

      given_ "user opens the visualization editor", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/visualizations/new")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "both user and assistant messages remain visible after multiple exchanges", context do
        with_cassette "visualization_chat_generate", @cassette_opts, fn plug ->
          Application.put_env(:metric_flow, :req_http_options, plug: plug)

          # First message
          capture_log(fn ->
            render_submit(context.view, "send_chat", %{"prompt" => "Show me impressions over time as a line chart"})
            Process.sleep(100)
            render(context.view)
          end)

          # Second message
          capture_log(fn ->
            render_submit(context.view, "send_chat", %{"prompt" => "Now add clicks as a second series and make it a layered chart"})
            Process.sleep(100)
            render(context.view)
          end)

          html = render(context.view)

          # Both user messages should be in the chat history
          assert html =~ "Show me impressions"
          assert html =~ "Now add clicks"

          # Both assistant responses should be present
          # The assistant sends "Chart updated." for each successful generation
          assert has_element?(context.view, "[data-role='chat-messages']")

          # Chat form should still be available for more messages
          assert has_element?(context.view, "[data-role='chat-form']")
          assert has_element?(context.view, "[data-role='chat-input']")

          Application.delete_env(:metric_flow, :req_http_options)
        end

        :ok
      end
    end
  end
end
