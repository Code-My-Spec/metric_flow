defmodule MetricFlowSpex.Criterion5055SavedVizInLibrarySpex do
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

  spex "Saved visualizations appear in the visualization library", fail_on_error_logs: false do
    scenario "after saving a generated chart, it appears in the visualizations list" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "user generates and saves a visualization", context do
        {:ok, view, _html} = live(context.owner_conn, "/reports/generate")

        with_cassette "report_generator_success", @cassette_opts, fn plug ->
          Application.put_env(:metric_flow, :req_http_options, plug: plug)

          capture_log(fn ->
            view
            |> render_change("update_prompt", %{"prompt" => "Show me clicks"})

            view
            |> render_submit("generate", %{"prompt" => "Show me clicks"})
          end)

          view
          |> render_change("update_save_name", %{"save_name" => "LLM Generated Chart"})

          view
          |> render_submit("save_visualization", %{"save_name" => "LLM Generated Chart"})

          Application.delete_env(:metric_flow, :req_http_options)
        end

        {:ok, context}
      end

      when_ "user navigates to the visualizations library", context do
        {:ok, view, html} = live(context.owner_conn, "/visualizations")
        {:ok, Map.merge(context, %{view: view, html: html})}
      end

      then_ "the saved visualization appears in the list", context do
        assert context.html =~ "LLM Generated Chart"
        :ok
      end
    end
  end
end
