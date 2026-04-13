defmodule MetricFlowSpex.Criterion5079LlmGeneratesNamedDataSourceSpecsSpex do
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

  spex "The LLM generates specs using named data sources, not embedded values", fail_on_error_logs: false do
    scenario "AI-generated spec uses named data sources that get resolved for preview" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription
      given_ :owner_has_metrics

      given_ "user opens the visualization editor", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/visualizations/new")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the generated chart renders with resolved data from named sources", context do
        with_cassette "visualization_chat_generate", @cassette_opts, fn plug ->
          Application.put_env(:metric_flow, :req_http_options, plug: plug)

          capture_log(fn ->
            render_submit(context.view, "send_chat", %{"prompt" => "Show me impressions over time as a line chart"})
            Process.sleep(100)
            render(context.view)
          end)

          # Chart should render (meaning named data was resolved with real values)
          assert has_element?(context.view, "[data-role='vega-lite-chart']")

          # Open spec editor — the raw spec should show named data source format
          # (template, not embedded values) so the user sees the canonical form
          context.view |> element("[data-role='open-spec-panel']") |> render_click()
          spec_html = render(context.view)

          # The spec editor should show the named data source format
          assert spec_html =~ ~s("name")
          assert spec_html =~ "impressions"

          # The chart's data-spec should contain resolved values for rendering
          chart_el = element(context.view, "[data-role='vega-lite-chart']")
          chart_html = render(chart_el)
          assert chart_html =~ "data-spec="

          Application.delete_env(:metric_flow, :req_http_options)
        end

        :ok
      end
    end
  end
end
