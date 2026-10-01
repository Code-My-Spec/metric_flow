defmodule MetricFlowSpex.ReportChartsRenderUsingVegaLiteSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Report charts render using Vega-Lite", criterion: 931 do
    scenario "viewing a report with charts renders them with Vega-Lite specifications" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "a report containing charts", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboards/new")

        view
        |> element("[data-role='template-card-marketing_overview']")
        |> render_click()

        {:ok, Map.put(context, :view, view)}
      end

      when_ "it is viewed", context do
        html = render(context.view)
        {:ok, Map.put(context, :html, html)}
      end

      then_ "the charts render using Vega-Lite specifications", context do
        assert has_element?(context.view, "[data-role='vega-lite-chart']")
        assert context.html =~ "vega-lite"
        {:ok, context}
      end
    end
  end
end
