defmodule MetricFlowSpex.Criterion794UserExpandsVisualizationWithinReportLayoutSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "User expands a visualization within the report layout", criterion: 794 do
    scenario "a user expands a visualization displayed in a report" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "a visualization displayed in a report", context do
        viz =
          MetricFlowSpex.Fixtures.create_visualization_for(context.owner_email, %{
            name: "Expandable Report",
            vega_spec: %{
              "$schema" => "https://vega.github.io/schema/vega-lite/v5.json",
              "mark" => "line",
              "encoding" => %{}
            }
          })

        {:ok, view, _html} = live(context.owner_conn, "/app/reports/#{viz.id}")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user expands it", context do
        assert has_element?(context.view, "[data-role='report-chart-expand']"),
               "Expected an expand control on the report's chart panel"

        {:ok, context}
      end

      then_ "it displays at the larger size within the layout", context do
        {:ok, context}
      end
    end
  end
end
