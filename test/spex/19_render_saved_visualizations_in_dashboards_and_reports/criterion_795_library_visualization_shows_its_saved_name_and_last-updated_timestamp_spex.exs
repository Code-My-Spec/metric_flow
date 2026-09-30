defmodule MetricFlowSpex.Criterion795LibraryVisualizationShowsNameAndTimestampSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Library visualization shows its saved name and last-updated timestamp", criterion: 795 do
    scenario "a visualization sourced from the visualization library is displayed with its saved name and last-updated timestamp" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "a visualization sourced from the visualization library", context do
        viz =
          MetricFlowSpex.Fixtures.create_visualization_for(context.owner_email, %{
            name: "Library Sourced Chart",
            vega_spec: %{
              "$schema" => "https://vega.github.io/schema/vega-lite/v5.json",
              "mark" => "line",
              "encoding" => %{}
            }
          })

        {:ok, Map.put(context, :viz, viz)}
      end

      when_ "a user views it in the library", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/visualizations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "its saved name and last-updated timestamp are displayed alongside it", context do
        html = render(context.view)
        assert html =~ context.viz.name

        assert has_element?(context.view, "[data-role='visualization-updated-at']"),
               "Expected the visualization card to show a last-updated timestamp"

        {:ok, context}
      end
    end
  end
end
