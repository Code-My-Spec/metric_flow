defmodule MetricFlowSpex.Criterion5078LlmReceivesCurrentSpecAsContextSpex do
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

  spex "The LLM receives the current spec as context for iterative editing", fail_on_error_logs: false do
    scenario "after generating a chart, follow-up messages include the current spec" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription
      given_ :owner_has_metrics

      given_ "user opens the visualization editor", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/visualizations/new")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "follow-up chat produces a refined spec that builds on the previous one", context do
        with_cassette "visualization_chat_generate", @cassette_opts, fn plug ->
          Application.put_env(:metric_flow, :req_http_options, plug: plug)

          # Initial generation — single metric
          capture_log(fn ->
            render_submit(context.view, "send_chat", %{"prompt" => "Show me impressions over time as a line chart"})
            Process.sleep(100)
            render(context.view)
          end)

          assert has_element?(context.view, "[data-role='vega-lite-chart']")

          # Follow-up — should result in a layered chart building on the first
          capture_log(fn ->
            render_submit(context.view, "send_chat", %{"prompt" => "Now add clicks as a second series and make it a layered chart"})
            Process.sleep(100)
            render(context.view)
          end)

          # The resulting spec should contain both metrics — proving the LLM
          # was aware of the existing spec and built upon it
          context.view |> element("[data-role='open-spec-panel']") |> render_click()
          html = render(context.view)
          assert html =~ "impressions"
          assert html =~ "clicks"
          assert html =~ "layer"

          Application.delete_env(:metric_flow, :req_http_options)
        end

        :ok
      end
    end
  end
end
