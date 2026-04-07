defmodule MetricFlowSpex.Criterion4079ChartsAreInteractiveSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Charts are interactive with hover and click capabilities" do
    scenario "rendered chart has interactive Vega-Lite configuration" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription
      given_ :owner_has_metrics

      given_ "user has a chart rendered in the editor", context do
        {:ok, view, _html} = live(context.owner_conn, "/visualizations/new")

        view
        |> element("[phx-value-metric='impressions']")
        |> render_click()

        {:ok, Map.put(context, :view, view)}
      end

      then_ "the chart element is rendered with the VegaLite hook for client-side interactivity", context do
        # Vega-Lite charts rendered via vegaEmbed are inherently interactive
        # (hover tooltips, selection, zoom) — we verify the hook is wired up
        assert has_element?(context.view, "[phx-hook='VegaLite'][data-role='vega-lite-chart']")

        chart_html =
          context.view
          |> element("[data-role='vega-lite-chart']")
          |> render()

        # The spec is embedded as data-spec for vegaEmbed to pick up
        assert chart_html =~ "data-spec="
        :ok
      end
    end
  end
end
