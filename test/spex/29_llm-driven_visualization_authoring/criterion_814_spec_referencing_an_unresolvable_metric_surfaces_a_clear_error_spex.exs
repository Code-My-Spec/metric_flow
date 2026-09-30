defmodule MetricFlowSpex.Criterion814UnresolvableMetricSurfacesClearErrorSpex do
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

  spex "Spec referencing an unresolvable metric surfaces a clear error",
    fail_on_error_logs: false,
    criterion: 814 do
    scenario "a spec naming a metric outside the account's available metrics surfaces a clear error" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription
      given_ :owner_has_metrics

      given_ "user opens the visualization editor", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/visualizations/new")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the LLM produces a spec referencing a metric name that does not exist in the account's available metrics", context do
        # No cassette exists yet for a response naming an unresolvable metric --
        # this needs to be recorded before this scenario can replay.
        with_cassette "visualization_chat_unresolvable_metric", @cassette_opts, fn plug ->
          Application.put_env(:metric_flow, :req_http_options, plug: plug)

          capture_log(fn ->
            render_submit(context.view, "send_chat", %{
              "prompt" => "Show me a chart of the discontinued_metric field"
            })

            Process.sleep(100)
            render(context.view)
          end)

          Application.delete_env(:metric_flow, :req_http_options)
        end

        {:ok, context}
      end

      then_ "the chat panel surfaces a clear error identifying the unresolvable metric", context do
        assert has_element?(context.view, "[data-role='chat-error']")

        chat_error =
          context.view
          |> element("[data-role='chat-error']")
          |> render()

        assert chat_error =~ "discontinued_metric"
        {:ok, context}
      end
    end
  end
end
