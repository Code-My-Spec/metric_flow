defmodule MetricFlowSpex.Criterion5051EachIterationUpdatesPreviewSpex do
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

  spex "Each LLM iteration updates the preview in real time", fail_on_error_logs: false do
    scenario "regenerating replaces the previous chart with the new one" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "user is on the report generator", context do
        {:ok, view, _html} = live(context.owner_conn, "/reports/generate")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "user generates two charts and the preview is updated", context do
        with_cassette "report_generator_success", @cassette_opts, fn plug ->
          Application.put_env(:metric_flow, :req_http_options, plug: plug)

          # First generation
          capture_log(fn ->
            context.view
            |> render_change("update_prompt", %{"prompt" => "Show me spend"})

            context.view
            |> render_submit("generate", %{"prompt" => "Show me spend"})
          end)

          # Second generation
          capture_log(fn ->
            context.view
            |> render_change("update_prompt", %{"prompt" => "Now show conversions"})

            context.view
            |> render_submit("generate", %{"prompt" => "Now show conversions"})
          end)

          # Both iterations should produce a chart
          assert has_element?(context.view, "[data-role='vega-lite-chart']")
          # The save section resets (not already saved)
          refute has_element?(context.view, "[data-role='save-confirmation']")

          Application.delete_env(:metric_flow, :req_http_options)
        end

        :ok
      end
    end
  end
end
