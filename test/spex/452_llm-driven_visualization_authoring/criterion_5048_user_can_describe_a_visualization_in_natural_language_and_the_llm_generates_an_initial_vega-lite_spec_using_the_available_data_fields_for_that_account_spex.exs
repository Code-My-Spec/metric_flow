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
    scenario "submitting a natural language prompt generates a chart spec" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "user is on the report generator", context do
        {:ok, view, _html} = live(context.owner_conn, "/reports/generate")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "user submits a prompt and a Vega-Lite chart is rendered", context do
        with_cassette "report_generator_success", @cassette_opts, fn plug ->
          Application.put_env(:metric_flow, :req_http_options, plug: plug)

          capture_log(fn ->
            context.view
            |> render_change("update_prompt", %{"prompt" => "Create a line chart showing impressions over the last 30 days"})

            context.view
            |> render_submit("generate", %{"prompt" => "Create a line chart showing impressions over the last 30 days"})
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
