defmodule MetricFlowSpex.Criterion881AiAcknowledgesWhenItCannotAnswerConfidentlySpex do
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

  spex "AI acknowledges when it cannot answer confidently", criterion: 881 do
    scenario "a user asks a question the available data cannot support a confident answer to" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "a user viewing the AI chat with no metric data available", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/chat")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the AI responds to a question it cannot confidently answer", context do
        with_cassette "chat_unanswerable_question", @cassette_opts, fn plug ->
          Application.put_env(:metric_flow, :test_llm_options, req_http_options: [plug: plug])

          capture_log(fn ->
            context.view
            |> form("form[phx-submit='send_message']", %{
              "content" => "What will my revenue be next quarter?"
            })
            |> render_submit()

            Process.sleep(100)
            render(context.view)
          end)

          Application.delete_env(:metric_flow, :test_llm_options)
        end

        {:ok, context}
      end

      then_ "it states that limitation rather than guessing or fabricating an explanation", context do
        html = render(context.view)
        assert has_element?(context.view, "[data-role='assistant-message']")

        refute html =~ ~r/\$[\d,]+(\.\d+)?/,
               "Expected the AI to acknowledge it cannot answer confidently rather than fabricating a specific figure"

        {:ok, context}
      end
    end
  end
end
