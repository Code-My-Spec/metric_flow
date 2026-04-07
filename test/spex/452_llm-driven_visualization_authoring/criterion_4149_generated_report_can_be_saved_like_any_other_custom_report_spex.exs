defmodule MetricFlowSpex.Criterion4149SaveGeneratedReportSpex do
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

  spex "Generated report can be saved like any other custom report", fail_on_error_logs: false do
    scenario "user can name and save a generated visualization" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "user is on the report generator", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/reports/generate")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "user generates a chart, saves it, and sees confirmation", context do
        with_cassette "report_generator_success", @cassette_opts, fn plug ->
          Application.put_env(:metric_flow, :req_http_options, plug: plug)

          capture_log(fn ->
            context.view
            |> render_change("update_prompt", %{"prompt" => "Show me impressions"})

            context.view
            |> render_submit("generate", %{"prompt" => "Show me impressions"})
          end)

          context.view
          |> render_change("update_save_name", %{"save_name" => "My Generated Report"})

          context.view
          |> render_submit("save_visualization", %{"save_name" => "My Generated Report"})

          html = render(context.view)
          assert has_element?(context.view, "[data-role='save-confirmation']")
          assert html =~ "Saved"
          assert html =~ "Visualizations"

          Application.delete_env(:metric_flow, :req_http_options)
        end

        :ok
      end
    end
  end
end
