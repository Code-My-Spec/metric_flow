defmodule MetricFlowSpex.Criterion239MultiMetricUsesLayerPerMetricSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Multi-metric visualizations use a Vega-Lite layer with a separate named data source per metric",
    criterion: 239 do
    scenario "a spec referencing two metrics renders with one layer entry per metric" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription
      given_ :owner_has_metrics

      given_ "user opens the visualization editor and spec panel", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/visualizations/new")

        view
        |> element("[data-role='open-spec-panel']")
        |> render_click()

        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user selects two metrics", context do
        context.view
        |> element("[phx-value-metric='impressions']")
        |> render_click()

        context.view
        |> element("[phx-value-metric='clicks']")
        |> render_click()

        {:ok, context}
      end

      then_ "the spec uses a layer with a separate named data source per metric", context do
        spec_text =
          context.view
          |> element("[data-role='vega-spec-textarea']")
          |> render()

        assert spec_text =~ "layer"
        assert spec_text =~ "impressions"
        assert spec_text =~ "clicks"
        {:ok, context}
      end
    end
  end
end
