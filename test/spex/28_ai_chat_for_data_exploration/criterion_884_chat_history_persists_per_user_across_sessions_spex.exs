defmodule MetricFlowSpex.Criterion884ChatHistoryPersistsPerUserAcrossSessionsSpex do
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

  spex "Chat history persists per user across sessions", criterion: 884 do
    scenario "a user returns to the chat in a later session" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription
      given_ :owner_has_metrics

      given_ "a user has previously chatted with the AI", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/chat")

        with_cassette "chat_history_seed_message", @cassette_opts, fn plug ->
          Application.put_env(:metric_flow, :test_llm_options, req_http_options: [plug: plug])

          capture_log(fn ->
            view
            |> form("form[phx-submit='send_message']", %{"content" => "How are my metrics trending?"})
            |> render_submit()

            Process.sleep(100)
            render(view)
          end)

          Application.delete_env(:metric_flow, :test_llm_options)
        end

        {:ok, context}
      end

      when_ "they return in a later session", context do
        {:ok, reopened_view, _html} = live(context.owner_conn, "/app/chat")
        {:ok, Map.put(context, :reopened_view, reopened_view)}
      end

      then_ "their prior chat history is still available", context do
        assert has_element?(context.reopened_view, "[data-role='session-item']"),
               "Expected the sidebar to show the prior chat session"

        {:ok, context}
      end
    end
  end
end
