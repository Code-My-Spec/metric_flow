defmodule MetricFlowSpex.Criterion799LlmGeneratesInitialSpecSpex do
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

  spex "LLM generates an initial spec from a natural language request", criterion: 799 do
    scenario "describing a chart in natural language produces a valid initial spec" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription
      given_ :owner_has_metrics

      given_ "a user in the authoring workspace with an account that has synced metrics", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/visualizations/new")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "they describe a desired chart in natural language", context do
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

      then_ "the LLM generates a valid initial Vega-Lite spec using the account's available metrics", context do
        assert has_element?(context.view, "[data-role='vega-lite-chart']")

        chart_html =
          context.view
          |> element("[data-role='vega-lite-chart']")
          |> render()

        assert chart_html =~ "data-spec="
        {:ok, context}
      end
    end
  end
end
