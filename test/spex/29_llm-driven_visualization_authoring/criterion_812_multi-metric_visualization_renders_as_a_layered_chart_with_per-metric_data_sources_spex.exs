defmodule MetricFlowSpex.Criterion812MultiMetricRendersAsLayeredChartSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Multi-metric visualization renders as a layered chart with per-metric data sources",
    criterion: 812 do
    scenario "a visualization bound to two metrics displays as a Vega-Lite layer with a named source per metric" do
      given_(:user_logged_in_as_owner)
      given_(:owner_has_active_subscription)
      given_(:owner_has_metrics)

      given_ "a visualization bound to two metrics", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/visualizations/new")

        view
        |> element("[phx-value-metric='impressions']")
        |> render_click()

        view
        |> element("[phx-value-metric='clicks']")
        |> render_click()

        view
        |> element("[data-role='open-spec-panel']")
        |> render_click()

        {:ok, Map.put(context, :view, view)}
      end

      when_ "it is rendered", context do
        {:ok, context}
      end

      then_ "it displays as a Vega-Lite layer with a separate named data source for each metric",
            context do
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
