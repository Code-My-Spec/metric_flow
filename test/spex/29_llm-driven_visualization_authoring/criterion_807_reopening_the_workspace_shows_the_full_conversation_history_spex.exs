defmodule MetricFlowSpex.Criterion807ReopeningShowsFullHistorySpex do
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

  spex "Reopening the workspace shows the full conversation history", criterion: 807 do
    scenario "returning to the workspace later in the same session still shows prior chat history" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription
      given_ :owner_has_metrics

      given_ "a user has exchanged several messages in an authoring session", context do
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
        |> render_change(%{"name" => "Reopened Chat History"})

        new_view
        |> element("[data-role='save-visualization-btn']")
        |> render_click()

        {:ok, index_view, _html} = live(context.owner_conn, "/app/visualizations")
        html = render(index_view)
        [_, viz_id] = Regex.run(~r/data-visualization-id="(\d+)"/, html)

        {:ok, Map.put(context, :viz_id, viz_id)}
      end

      when_ "they return to the workspace later in the same session", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/visualizations/#{context.viz_id}/edit")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the chat panel still shows the full history of user and assistant messages", context do
        html = render(context.view)
        assert html =~ "Show me impressions over time as a line chart",
               "Expected the chat panel to still show the earlier message after reopening the workspace"

        {:ok, context}
      end
    end
  end
end
