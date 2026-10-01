defmodule MetricFlowSpex.Criterion811SpecUsesNamedSourcesAndBindsJoinTableSpex do
  use MetricFlowSpex.Case, async: false
  import Phoenix.LiveViewTest
  import ExUnit.CaptureLog

  import MetricFlowSpex.SharedGivens

  spex "Spec uses named data sources and binds metrics via the join table", criterion: 811 do
    scenario "a spec generated for a metric is saved with a named data source and the metric binding persists" do
      given_(:user_logged_in_as_owner)
      given_(:owner_has_active_subscription)
      given_(:owner_has_metrics)

      given_ "the LLM generates a spec referencing an account metric", context do
        {:ok, new_view, _html} = live(context.owner_conn, "/app/visualizations/new")

        new_view
        |> element("[data-role='open-spec-panel']")
        |> render_click()

        Application.put_env(
          :metric_flow,
          :command_runner,
          MetricFlowTest.VizChatStub.generate_initial()
        )

        capture_log(fn ->
          render_submit(new_view, "send_chat", %{
            "prompt" => "Show me impressions over time as a line chart"
          })

          Process.sleep(100)
          render(new_view)
        end)

        Application.delete_env(:metric_flow, :command_runner)

        {:ok, Map.put(context, :view, new_view)}
      end

      when_ "the spec is created", context do
        spec_text =
          context.view
          |> element("[data-role='vega-spec-textarea']")
          |> render()

        context.view
        |> element("form[phx-change='validate_name']")
        |> render_change(%{"name" => "Named Source Bound Chart"})

        context.view
        |> element("[data-role='save-visualization-btn']")
        |> render_click()

        {:ok, index_view, _html} = live(context.owner_conn, "/app/visualizations")
        html = render(index_view)
        [_, viz_id] = Regex.run(~r/data-visualization-id="(\d+)"/, html)

        {:ok, Map.merge(context, %{spec_text: spec_text, viz_id: viz_id})}
      end

      then_ "it references the metric by name using Vega-Lite named data sources, and the visualization_metrics join table binds the metric",
            context do
        refute context.spec_text =~ "&quot;values&quot;"
        assert context.spec_text =~ "impressions"

        {:ok, edit_view, _html} =
          live(context.owner_conn, "/app/visualizations/#{context.viz_id}/edit")

        assert render(edit_view) =~ "impressions"
        {:ok, context}
      end
    end
  end
end
