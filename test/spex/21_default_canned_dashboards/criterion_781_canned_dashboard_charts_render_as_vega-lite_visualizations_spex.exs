defmodule MetricFlowSpex.CannedDashboardChartsRenderAsVegaLiteVisualizationsSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Canned dashboard charts render as Vega-Lite visualizations", criterion: 781 do
    scenario "a canned dashboard's charts are rendered using Vega-Lite" do
      given_(:user_logged_in_as_owner)

      given_ "a canned dashboard is displayed", context do
        MetricFlowSpex.Fixtures.create_canned_dashboard!(
          context.owner_email,
          "Marketing Overview"
        )

        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_ads)

        MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{
          provider: :google_ads,
          metric_name: "clicks",
          value: 42.0
        })

        dashboard_id =
          context.owner_conn
          |> live("/app/dashboards")
          |> then(fn {:ok, view, _html} -> view end)
          |> element("[data-role='dashboard-card']", "Marketing Overview")
          |> render()
          |> then(fn html ->
            [_, id] = Regex.run(~r/data-dashboard-id="(\d+)"/, html)
            id
          end)

        {:ok, template_view, _html} = live(context.owner_conn, "/app/dashboards/#{dashboard_id}")
        {:ok, Map.put(context, :template_view, template_view)}
      end

      when_ "its charts are rendered", context do
        {:ok, context}
      end

      then_ "they are rendered using Vega-Lite specifications", context do
        assert has_element?(
                 context.template_view,
                 "[data-role='vega-lite-chart'][phx-hook='VegaLite']"
               )

        {:ok, context}
      end
    end
  end
end
