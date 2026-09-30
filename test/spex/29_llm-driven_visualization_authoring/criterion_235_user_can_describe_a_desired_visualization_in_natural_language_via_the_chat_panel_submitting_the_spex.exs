defmodule MetricFlowSpex.Criterion235SendChatDispatchesLlmCallSpex do
  use MetricFlowSpex.Case, async: false
  import Phoenix.LiveViewTest
  import ExUnit.CaptureLog
  import ReqCassette

  import MetricFlowSpex.SharedGivens

  @cassette_opts [
    cassette_dir: "test/cassettes/ai",
    filter_request_headers: ["x-api-key", "authorization"],
    mode: :replay,
    match_requests_on: [:method, :uri]
  ]

  spex "User can describe a desired visualization in natural language via the chat panel; submitting the message dispatches a send_chat event that calls the LLM and streams the response back into the chat panel",
    criterion: 235 do
    scenario "submitting the chat form dispatches send_chat and the response appears in the chat panel" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription
      given_ :owner_has_metrics

      given_ "user opens the visualization editor", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/visualizations/new")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user submits a natural-language chat message", context do
        with_cassette "visualization_chat_generate", @cassette_opts, fn plug ->
          Application.put_env(:metric_flow, :req_http_options, plug: plug)

          capture_log(fn ->
            render_submit(context.view, "send_chat", %{"prompt" => "Show me impressions over time as a line chart"})
            Process.sleep(100)
            render(context.view)
          end)

          Application.delete_env(:metric_flow, :req_http_options)
        end

        {:ok, context}
      end

      then_ "the user's message and the LLM's response both appear in the chat panel", context do
        html = render(context.view)
        assert html =~ "Show me impressions over time as a line chart"
        assert has_element?(context.view, "[data-role='chat-messages']")
        {:ok, context}
      end
    end
  end
end
