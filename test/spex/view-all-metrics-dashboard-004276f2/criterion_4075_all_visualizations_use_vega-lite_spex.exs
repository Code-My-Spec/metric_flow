defmodule MetricFlowSpex.AllVisualizationsUseVegaLiteSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "All visualizations use Vega-Lite" do
    scenario "dashboard page includes Vega-Lite visualization containers" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page renders at least one Vega-Lite chart container", context do
        assert has_element?(context.view, "[data-role='vega-lite-chart']") or
                 has_element?(context.view, "[data-chart-type='vega-lite']") or
                 has_element?(context.view, "[phx-hook='VegaLite']") or
                 has_element?(context.view, "[phx-hook='VegaLiteChart']") or
                 render(context.view) =~ "vega-lite" or
                 render(context.view) =~ "vega_lite"

        :ok
      end
    end

    scenario "dashboard page references Vega-Lite or vega-embed scripting" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the rendered HTML includes a vega-embed hook or Vega-Lite chart spec attribute", context do
        html = render(context.view)

        assert html =~ "vega-embed" or
                 html =~ "vegaEmbed" or
                 html =~ "vega-lite" or
                 html =~ "VegaLite" or
                 html =~ ~s(data-role="vega-lite-chart") or
                 html =~ ~s(phx-hook="VegaLite") or
                 has_element?(context.view, "[data-role='vega-lite-chart']")

        :ok
      end
    end

    scenario "dashboard page does not use Chart.js canvas elements for charts" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "no Chart.js canvas elements are rendered on the page", context do
        refute has_element?(context.view, "canvas[data-chartjs]")
        refute has_element?(context.view, "[data-chart-library='chartjs']")
        refute render(context.view) =~ "chart.js"
        :ok
      end
    end

    scenario "dashboard page does not use D3 SVG chart containers" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "no D3-specific SVG chart containers are rendered on the page", context do
        refute has_element?(context.view, "[data-chart-library='d3']")
        refute has_element?(context.view, "svg[data-d3-chart]")
        refute render(context.view) =~ "d3.js"
        :ok
      end
    end

    scenario "every chart container on the dashboard is a Vega-Lite container" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "all visualization containers use the Vega-Lite chart role or hook", context do
        # If any chart containers exist, they must all be Vega-Lite (not mixed libraries).
        # We assert there are no non-Vega-Lite chart markers alongside any chart containers.
        html = render(context.view)

        has_vega_lite =
          html =~ "vega-lite" or
            html =~ "VegaLite" or
            html =~ "vega-embed" or
            has_element?(context.view, "[data-role='vega-lite-chart']") or
            has_element?(context.view, "[phx-hook='VegaLite']")

        has_other_charting_library =
          html =~ "chart.js" or
            html =~ "Chart.js" or
            html =~ "highcharts" or
            html =~ "Highcharts" or
            html =~ "apexcharts" or
            html =~ "ApexCharts"

        # There should be Vega-Lite chart references and no other charting library references.
        assert has_vega_lite, "Expected Vega-Lite chart containers to be present on the dashboard"
        refute has_other_charting_library, "Expected no other charting libraries (Chart.js, Highcharts, etc.) to be used"

        :ok
      end
    end
  end
end
