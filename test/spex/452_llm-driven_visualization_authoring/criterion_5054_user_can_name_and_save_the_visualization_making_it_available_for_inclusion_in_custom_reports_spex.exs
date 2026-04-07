defmodule MetricFlowSpex.Criterion5054NameAndSaveVisualizationSpex do
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

  spex "User can name and save the visualization for inclusion in reports", fail_on_error_logs: false do
    scenario "save section appears after generation with name input" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "user is on the report generator", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/reports/generate")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "user generates a chart and a save section is displayed", context do
        with_cassette "report_generator_success", @cassette_opts, fn plug ->
          Application.put_env(:metric_flow, :req_http_options, plug: plug)

          capture_log(fn ->
            context.view
            |> render_change("update_prompt", %{"prompt" => "Show me a chart"})

            context.view
            |> render_submit("generate", %{"prompt" => "Show me a chart"})
          end)

          assert has_element?(context.view, "[data-role='save-section']")
          assert has_element?(context.view, "[data-role='save-name-input']")
          assert has_element?(context.view, "[data-role='save-visualization-btn']")

          Application.delete_env(:metric_flow, :req_http_options)
        end

        :ok
      end
    end

    scenario "saving with a blank name shows an error" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "user is on the report generator", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/reports/generate")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "user generates a chart and tries to save without a name", context do
        with_cassette "report_generator_success", @cassette_opts, fn plug ->
          Application.put_env(:metric_flow, :req_http_options, plug: plug)

          capture_log(fn ->
            context.view
            |> render_change("update_prompt", %{"prompt" => "Show me a chart"})

            context.view
            |> render_submit("generate", %{"prompt" => "Show me a chart"})
          end)

          context.view
          |> render_change("update_save_name", %{"save_name" => ""})

          context.view
          |> render_submit("save_visualization", %{"save_name" => ""})

          assert has_element?(context.view, "[data-role='save-error']")
          html = render(context.view)
          assert html =~ "required" || html =~ "Name"

          Application.delete_env(:metric_flow, :req_http_options)
        end

        :ok
      end
    end
  end
end
