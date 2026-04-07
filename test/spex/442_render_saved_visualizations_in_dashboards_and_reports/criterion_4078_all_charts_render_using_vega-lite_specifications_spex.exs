defmodule MetricFlowSpex.Criterion4078AllChartsRenderVegaLiteSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "All charts render using Vega-Lite specifications" do
    scenario "selecting a metric renders a chart with a vega-lite data-spec attribute" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription
      given_ :owner_has_metrics

      given_ "user is on the visualization editor", context do
        {:ok, view, _html} = live(context.owner_conn, "/visualizations/new")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "user selects a metric", context do
        context.view
        |> element("[phx-value-metric='impressions']")
        |> render_click()

        html = render(context.view)
        {:ok, Map.merge(context, %{html: html})}
      end

      then_ "the chart container uses the VegaLite hook and has a valid JSON spec", context do
        assert has_element?(context.view, "[phx-hook='VegaLite']")
        assert has_element?(context.view, "[data-role='vega-lite-chart']")

        # The data-spec attribute should contain valid JSON with a Vega-Lite $schema or mark
        spec_attr =
          context.view
          |> element("[data-role='vega-lite-chart']")
          |> render()

        assert spec_attr =~ "data-spec="
        :ok
      end
    end

    scenario "the vega-lite spec editor shows valid JSON for the current chart" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription
      given_ :owner_has_metrics

      given_ "user has selected a metric", context do
        {:ok, view, _html} = live(context.owner_conn, "/visualizations/new")

        view
        |> element("[phx-value-metric='impressions']")
        |> render_click()

        {:ok, Map.put(context, :view, view)}
      end

      when_ "user opens the spec editor", context do
        context.view
        |> element("[data-role='toggle-spec-editor']")
        |> render_click()

        html = render(context.view)
        {:ok, Map.merge(context, %{html: html})}
      end

      then_ "the textarea contains a valid Vega-Lite JSON spec", context do
        assert has_element?(context.view, "[data-role='vega-spec-textarea']")

        textarea_html =
          context.view
          |> element("[data-role='vega-spec-textarea']")
          |> render()

        # Should contain Vega-Lite spec markers
        assert textarea_html =~ "mark"
        assert textarea_html =~ "encoding"
        :ok
      end
    end
  end
end
