defmodule MetricFlowSpex.Criterion238AutoUpdatesJoinTableEntriesSpex do
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

  spex "When the LLM generates or updates a spec, the system automatically creates or updates visualization_metrics join table entries to bind every referenced metric name to the visualization",
    criterion: 238 do
    scenario "saving a chat-generated visualization binds its referenced metric via the join table" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription
      given_ :owner_has_metrics

      given_ "the LLM generates a spec referencing a metric", context do
        {:ok, new_view, _html} = live(context.owner_conn, "/app/visualizations/new")

        with_cassette "visualization_chat_generate", @cassette_opts, fn plug ->
          Application.put_env(:metric_flow, :req_http_options, plug: plug)

          capture_log(fn ->
            render_submit(new_view, "send_chat", %{"prompt" => "Show me impressions over time as a line chart"})
            Process.sleep(100)
            render(new_view)
          end)

          Application.delete_env(:metric_flow, :req_http_options)
        end

        new_view
        |> element("form[phx-change='validate_name']")
        |> render_change(%{"name" => "Auto Bound Chart"})

        new_view
        |> element("[data-role='save-visualization-btn']")
        |> render_click()

        {:ok, index_view, _html} = live(context.owner_conn, "/app/visualizations")
        html = render(index_view)
        [_, viz_id] = Regex.run(~r/data-visualization-id="(\d+)"/, html)

        {:ok, Map.put(context, :viz_id, viz_id)}
      end

      when_ "the user reopens the visualization for editing", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/visualizations/#{context.viz_id}/edit")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the visualization's bound metric is restored from the join table", context do
        assert render(context.view) =~ "impressions"
        {:ok, context}
      end
    end
  end
end
