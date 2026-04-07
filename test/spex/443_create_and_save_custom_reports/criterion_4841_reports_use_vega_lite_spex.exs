defmodule MetricFlowSpex.Criterion4841ReportsUseVegaLiteSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Reports use Vega-Lite for chart rendering" do
    scenario "the all-metrics dashboard renders charts with VegaLite hook" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription
      given_ :owner_with_integrations

      when_ "user views the main dashboard", context do
        {:ok, view, html} = live(context.owner_conn, "/dashboard")
        {:ok, Map.merge(context, %{view: view, html: html})}
      end

      then_ "charts are rendered using the VegaLite hook", context do
        html = render(context.view)
        # The dashboard uses VegaLite for chart rendering
        assert html =~ "VegaLite" || html =~ "vega-lite" || has_element?(context.view, "[phx-hook='VegaLite']")
        :ok
      end
    end
  end
end
