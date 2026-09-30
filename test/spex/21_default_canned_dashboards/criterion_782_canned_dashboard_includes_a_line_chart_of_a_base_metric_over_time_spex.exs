defmodule MetricFlowSpex.CannedDashboardIncludesALineChartOfABaseMetricOverTimeSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Canned dashboard includes a line chart of a base metric over time", criterion: 782 do
    scenario "a user views a canned dashboard such as Marketing Overview" do
      given_(:user_logged_in_as_owner)

      given_ "a canned dashboard such as Marketing Overview", context do
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

      when_ "a user views it", context do
        {:ok, context}
      end

      then_ "it includes at least one line chart showing a base metric (e.g., clicks or spend) over time",
            context do
        spec_json =
          context.template_view
          |> element("[data-role='vega-lite-chart']")
          |> render()

        # The spec is JSON embedded in an HTML attribute, so quotes are
        # HTML-escaped in the rendered markup (" becomes &quot;).
        assert spec_json =~ ~s(&quot;type&quot;:&quot;line&quot;),
               "Expected the chart's Vega-Lite spec to use a line mark, got: #{spec_json}"

        {:ok, context}
      end
    end
  end
end
