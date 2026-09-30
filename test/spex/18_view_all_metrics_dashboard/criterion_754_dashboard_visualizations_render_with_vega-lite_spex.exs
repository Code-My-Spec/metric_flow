defmodule MetricFlowSpex.DashboardVisualizationsRenderWithVegaLiteSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Dashboard visualizations render with Vega-Lite", criterion: 754 do
    scenario "the dashboard's chart renders using the Vega-Lite hook when there is data to display" do
      given_(:user_logged_in_as_owner)

      given_ "the dashboard has data to display", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_ads)

        MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{
          provider: :google_ads,
          metric_name: "clicks",
          value: 42.0
        })

        {:ok, context}
      end

      when_ "its charts render", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "they are rendered using Vega-Lite", context do
        assert has_element?(context.view, "[data-role='vega-lite-chart'][phx-hook='VegaLite']")
        {:ok, context}
      end
    end
  end
end
